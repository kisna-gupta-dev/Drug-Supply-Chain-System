const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DrugSupplyChain", function () {
  let drugSupplyChain, escrow, priceFeed, handlingAddresses;
  let owner, manufacturer, distributor, retailer, other;

  beforeEach(async function () {
    [owner, manufacturer, distributor, retailer, other] =
      await ethers.getSigners();

    const MockV3Aggregator =
      await ethers.getContractFactory("MockV3Aggregator");
    priceFeed = await MockV3Aggregator.connect(owner).deploy(18, 4358000);
    await priceFeed.waitForDeployment();

    const Escrow = await ethers.getContractFactory("Escrow");
    escrow = await Escrow.connect(owner).deploy();
    await escrow.waitForDeployment();

    const HandlingAddresses =
      await ethers.getContractFactory("HandlingAddresses");
    handlingAddresses = await HandlingAddresses.connect(owner).deploy();
    await handlingAddresses.waitForDeployment();

    const DrugSupplyChain = await ethers.getContractFactory("DrugSupplyChain");
    drugSupplyChain = await DrugSupplyChain.connect(owner).deploy(
      priceFeed.target,
      escrow.target,
      handlingAddresses.target,
    );
    await drugSupplyChain.waitForDeployment();

    await handlingAddresses
      .connect(owner)
      .addManufacturer(manufacturer.address);
    await handlingAddresses.connect(owner).addDistributor(distributor.address);
    await handlingAddresses.connect(owner).addRetailer(retailer.address);
  });

  it("drugSupplyChain deployed successfully", async function () {
    expect(drugSupplyChain.target).to.be.properAddress;
  });
  it("drugSupplyChain has the correct owner", async function () {
    const ownerInContract = await drugSupplyChain.owner();
    expect(ownerInContract).to.equal(owner.address);
  });
  it("escrow address is correct", async function () {
    const escrowAddr = await drugSupplyChain.escrowContract();
    expect(escrowAddr).to.equal(escrow.target);
  });
});
