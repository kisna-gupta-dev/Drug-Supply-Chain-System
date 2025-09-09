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
    drugSupplyChain.MANUFACTURER_ROLE,
    addr1.address,
  );
  await drugSupplyChain.grantRole(
    drugSupplyChain.DISTRIBUTOR_ROLE,
    addr2.address,
  );
  await drugSupplyChain.grantRole(drugSupplyChain.RETAILER_ROLE, addr3.address);
  return (
    deployer,
    addr1,
    addr2,
    addr3,
    escrow,
    escrowaddress,
    mockV3Aggregator,
    mockV3Aggregatoraddress,
    drugSupplyChain,
    drugSupplyChainAddress
  );
}

describe("Escrow", async function () {
  it("escrow deployed successfully", async function () {
    const { escrowaddress } = await loadFixture(setupFixture);
    expect(ethers.isAddress(escrowaddress)).to.be.true;
  });
  it("escrow has the correct owner", async function () {
    const { escrow, deployer } = await loadFixture(setupFixture);
    const owner = await escrow.owner();
    assert.equal(owner, deployer.address);
  });
});

describe("DrugSupplyChain", function () {
  beforeEach(async function () {});
  it("");
});

describe("upKeep", function () {
  beforeEach(async function () {});
  it("");
});

describe("BasicMechanism", function () {
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
