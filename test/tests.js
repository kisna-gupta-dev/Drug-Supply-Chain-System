const { expect } = require("chai");
const { ethers, assert } = require("hardhat");
const {
  loadFixture,
  time,
} = require("@nomicfoundation/hardhat-network-helpers");

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

  console.log("-----------------------------------------------------");
  console.log(await drugSupplyChain.MANUFACTURER_ROLE());
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

function findEvent(receipt, contract, eventName) {
  for (const log of receipt.logs) {
    try {
      const parsed = contract.interface.parseLog(log);
      console.log(parsed.name);
      if (parsed.name === eventName) {
        return parsed;
      }
    } catch (error) {
      return console.error(error.message);
    }
  }
}
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
    const tx2 = await drugSupplyChain
      .connect(deployer)
      .grantRole(await drugSupplyChain.MANUFACTURER_ROLE(), addr1.address);
    const rece = await tx2.wait();
    console.log(rece);
    const parsed = findEvent(rece, drugSupplyChain, "RoleGranted");

    const BasicMechanism = await ethers.getContractFactory("BasicMechanism");
    const basicMechanism = await BasicMechanism.connect(deployer).deploy(
      mockV3Aggregatoraddress,
      escrowaddress,
    );
    console.log("BasicMechanism deployed to:", deployer.address);
    this.expiryDate = Math.floor(new Date("2026-01-01").getTime() / 1000);
    this.drugSupplyChain = drugSupplyChain;
    this.basicMechanism = basicMechanism;
    this.addr1 = addr1;
    this.addr2 = addr2;

    const tx = await this.basicMechanism
      .connect(addr1)
      .createBatch(addr1.address, this.expiryDate, 1000, ethers.ZeroAddress);

    // await this.basicMechanism.on("BatchCreated", (batchId, timestamp) => {
    //   this.batchId = batchId;
    //   this.timestamp = timestamp;
    // });
  });

  it("Only distributor can buy batch from Manufacturer", async function () {
    const {
      basicMechanism,
      expiryDate,
      addr1,
      addr2,
      drugSupplyChain,
      batchId,
      timestamp,
    } = this;
    let hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.MANUFACTURER_ROLE(),
      addr1.address,
    );
    expect(hasRole).to.be.true;
    hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.DISTRIBUTOR_ROLE(),
      addr2.address,
    );
    expect(hasRole).to.be.true;

    expect(await basicMechanism.buyBatchDistributor(batchId, timestamp));
  });
});
// it("Manufacturer can create batch", async function () {
//   const { basicMechanism, expiryDate, addr1, addr2 } = this;
//   const ipfsHash = ethers.ZeroAddress; // Example IPFS hash
//   await expect(
//     basicMechanism
//       .connect(addr1)
//       .createBatch(addr1.address, expiryDate, 1000, ipfsHash),
//   ).to.not.be.reverted;
// });
it("Only Manufacturer can create batch", async function () {
  const { basicMechanism, expiryDate, addr1, addr2 } = this;
  const ipfsHash = ethers.ZeroAddress; // Example IPFS hash
  await expect(
    basicMechanism
      .connect(addr2)
      .createBatch(addr1.address, expiryDate, 1000, ipfsHash),
  ).to.be.reverted;
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

module.exports = {
  setupFixture,
};
