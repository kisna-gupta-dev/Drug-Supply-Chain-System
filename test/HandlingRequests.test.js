const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Handling Requests", async function () {
  let drugSupplyChain,
    escrow,
    mockV3Aggregator,
    handlingAddressses,
    handlingRequests,
    basicMechanism;
  let admin, manufacturer, distributor, retailer, other;
  let batchId;
  beforeEach(async function () {
    [admin, manufacturer, distributor, retailer, other] =
      await ethers.getSigners();

    const Escrow = await ethers.getContractFactory("Escrow");
    escrow = await Escrow.connect(admin).deploy();
    await escrow.waitForDeployment();

    const HandlingAddresses =
      await ethers.getContractFactory("HandlingAddresses");
    handlingAddressses = await HandlingAddresses.connect(admin).deploy();
    await handlingAddressses.waitForDeployment();

    const MockV3Aggregator =
      await ethers.getContractFactory("MockV3Aggregator");
    mockV3Aggregator = await MockV3Aggregator.connect(admin).deploy(
      18,
      4358000000,
    );
    await mockV3Aggregator.waitForDeployment();

    const DrugSupplyChain = await ethers.getContractFactory("DrugSupplyChain");
    drugSupplyChain = await DrugSupplyChain.connect(admin).deploy(
      mockV3Aggregator.target,
      escrow.target,
      handlingAddressses.target,
    );
    await drugSupplyChain.waitForDeployment();

    const BasicMechanism = await ethers.getContractFactory("BasicMechanism");
    basicMechanism = await BasicMechanism.connect(admin).deploy(
      mockV3Aggregator.target,
      escrow.target,
      handlingAddressses.target,
    );
    await basicMechanism.waitForDeployment();

    const HandlingRequests =
      await ethers.getContractFactory("HandlingRequests");
    handlingRequests = await HandlingRequests.connect(admin).deploy(
      mockV3Aggregator.target,
      escrow.target,
      handlingAddressses.target,
    );
    await handlingRequests.waitForDeployment();

    await handlingAddressses
      .connect(admin)
      .addManufacturer(manufacturer.address);
    await handlingAddressses.connect(admin).addDistributor(distributor.address);
    await handlingAddressses.connect(admin).addRetailer(retailer.address);

    const expiry = Math.floor(Date.now() / 1000) + 86400; // 1 day ahead
    const price = 100;
    const tx = await basicMechanism
      .connect(manufacturer)
      .createBatch(manufacturer.address, expiry, price, other.address);

    const receipt = await tx.wait();
    const events = await basicMechanism.queryFilter(
      "BatchCreated",
      receipt.blockNumber,
    );
    const event = events[0];
    batchId = event.args[0];
  });

  describe("Request Return", async function () {
    
  });
});
