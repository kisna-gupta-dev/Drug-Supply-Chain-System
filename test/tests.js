const { expect } = require("chai");
const { ethers, assert } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

async function setupFixture() {
  const [deployer, addr1, addr2, addr3] = await ethers.getSigners();

  const Escrow = await ethers.getContractFactory("Escrow");
  const escrow = await Escrow.connect(deployer).deploy();
  await escrow.waitForDeployment();
  const escrowaddress = escrow.target;

  const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
  const mockV3Aggregator = await MockV3Aggregator.connect(deployer).deploy(
    18,
    435800000000,
  );
  await mockV3Aggregator.waitForDeployment();
  const mockV3Aggregatoraddress = mockV3Aggregator.target;

  const DrugSupplyChain = await ethers.getContractFactory("DrugSupplyChain");
  const drugSupplyChain = await DrugSupplyChain.connect(deployer).deploy(
    mockV3Aggregatoraddress,
    escrowaddress,
  );
  await drugSupplyChain.waitForDeployment();
  const drugSupplyChainAddress = drugSupplyChain.target;

  await drugSupplyChain.grantRole(
    await drugSupplyChain.MANUFACTURER_ROLE(),
    addr1.address,
  );
  await drugSupplyChain.grantRole(
    await drugSupplyChain.DISTRIBUTOR_ROLE(),
    addr2.address,
  );
  await drugSupplyChain.grantRole(
    await drugSupplyChain.RETAILER_ROLE(),
    addr3.address,
  );

  return {
    deployer,
    addr1,
    addr2,
    addr3,
    escrow,
    escrowaddress,
    mockV3Aggregator,
    mockV3Aggregatoraddress,
    drugSupplyChain,
    drugSupplyChainAddress,
  };
}

describe("Escrow", async function () {
  it("escrow deployed successfully", async function () {
    const { escrowaddress } = await loadFixture(setupFixture);
    expect(ethers.isAddress(escrowaddress)).to.be.true;
  });
  it("escrow has the correct owner", async function () {
    const { escrow, deployer } = await loadFixture(setupFixture);
    const owner = await escrow.owner();
    expect(owner).to.equal(deployer.address);
  });
});

describe("DrugSupplyChain", function () {
  it("drugSupplyChain deployed successfully", async function () {
    const { drugSupplyChainAddress } = await loadFixture(setupFixture);
    expect(ethers.isAddress(drugSupplyChainAddress)).to.be.true;
  });
  it("drugSupplyChain has the correct owner", async function () {
    const { drugSupplyChain, deployer } = await loadFixture(setupFixture);
    const owner = await drugSupplyChain.owner();
    expect(owner).to.equal(deployer.address);
  });
  it("escrow address is correct", async function () {
    const { drugSupplyChain, escrowaddress } = await loadFixture(setupFixture);
    const escrowAddr = await drugSupplyChain.escrowContract();
    expect(escrowAddr).to.equal(escrowaddress);
  });
  it("Default admin role is assigned to deployer", async function () {
    const { drugSupplyChain, deployer } = await loadFixture(setupFixture);
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.DEFAULT_ADMIN_ROLE(),
      deployer.address,
    );
    expect(hasRole).to.be.true;
  });
  it("Manufacturer role is assigned to addr1", async function () {
    const { drugSupplyChain, addr1 } = await loadFixture(setupFixture);
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.MANUFACTURER_ROLE(),
      addr1.address,
    );
    expect(hasRole).to.be.true;
  });
  it("Distributor role is assigned to addr2", async function () {
    const { drugSupplyChain, addr2 } = await loadFixture(setupFixture);
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.DISTRIBUTOR_ROLE(),
      addr2.address,
    );
    expect(hasRole).to.be.true;
  });
  it("Retailer role is assigned to addr3", async function () {
    const { drugSupplyChain, addr3 } = await loadFixture(setupFixture);
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.RETAILER_ROLE(),
      addr3.address,
    );
    expect(hasRole).to.be.true;
  });
});

describe("BasicMechanism", function () {
  beforeEach(async function () {
    const {
      mockV3Aggregatoraddress,
      escrowaddress,
      deployer,
      drugSupplyChain,
      addr1,
      addr2,
    } = await loadFixture(setupFixture);

    const BasicMechanism = await ethers.getContractFactory("BasicMechanism");
    this.basicMechanism = await BasicMechanism.connect(deployer).deploy(
      mockV3Aggregatoraddress,
      escrowaddress,
    );
    await this.basicMechanism.waitForDeployment();

    this.expiryDate = Math.floor(new Date("2026-01-01").getTime() / 1000);
    this.drugSupplyChain = drugSupplyChain;
    this.addr1 = addr1;
    this.addr2 = addr2;
    
  });

  it("Only Manufacturer can create batch", async function () {
    const { basicMechanism, expiryDate, addr1, addr2 } = this;
    const ipfsHash = ethers.ZeroAddress; // Example IPFS hash
    const role = await basicMechanism.MANUFACTURER_ROLE();
    const add = ethers.getAddress(addr2.address);
    const Manufacturer = ethers.getAddress(addr1.address);
    await expect(
      basicMechanism
        .connect(addr2)
        .createBatch(Manufacturer, expiryDate, 1000, ipfsHash),
    ).to.be.reverted;
  });

  it("Only distributor can buy batch from Manufacturer", async function () {
    const { basicMechanism, expiryDate, addr1, addr2, drugSupplyChain } = this;
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.MANUFACTURER_ROLE(),
      addr1.address,
    );
    expect(hasRole).to.be.true;
    hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.DISTRIBUTOR_ROLE(),
      addr2.address,
    );
    expect(hasRole).to.be.true;
    
    expect(await basicMechanism.buyBatchDistriubutor(batchId,productPrice))
  });
});

describe("upKeep", function () {
  beforeEach(async function () {});
  it("");
});

describe("HandlingAddresses", function () {
  beforeEach(async function () {});
  it("");
});

describe("ResellMechanism", function () {
  beforeEach(async function () {});
  it("");
});

describe("HandlingRequests", function () {
  beforeEach(async function () {});
  it("");
});
