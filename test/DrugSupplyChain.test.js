const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DrugSupplyChain", function () {
  let drugSupplyChain, escrow, priceFeed;
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

    const DrugSupplyChain = await ethers.getContractFactory("DrugSupplyChain");
    drugSupplyChain = await DrugSupplyChain.connect(owner).deploy(
      priceFeed.target,
      escrow.target,
    );
    await drugSupplyChain.waitForDeployment();

    const MANUFACTURER_ROLE = await drugSupplyChain.MANUFACTURER_ROLE();
    const DISTRIBUTOR_ROLE = await drugSupplyChain.DISTRIBUTOR_ROLE();
    const RETAILER_ROLE = await drugSupplyChain.RETAILER_ROLE();

    await drugSupplyChain
      .connect(owner)
      .grantRole(MANUFACTURER_ROLE, manufacturer.address);
    await drugSupplyChain
      .connect(owner)
      .grantRole(DISTRIBUTOR_ROLE, distributor.address);
    await drugSupplyChain
      .connect(owner)
      .grantRole(RETAILER_ROLE, retailer.address);
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
  it("Default admin role is assigned to deployer", async function () {
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.DEFAULT_ADMIN_ROLE(),
      owner.address,
    );
    expect(hasRole).to.be.true;
  });
  it("Manufacturer role is assigned to manufacturer address", async function () {
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.MANUFACTURER_ROLE(),
      manufacturer.address,
    );
    expect(hasRole).to.be.true;
  });
  it("Distributor role is assigned to distributor address", async function () {
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.DISTRIBUTOR_ROLE(),
      distributor.address,
    );
    expect(hasRole).to.be.true;
  });
  it("Retailer role is assigned to reialer address", async function () {
    const hasRole = await drugSupplyChain.hasRole(
      await drugSupplyChain.RETAILER_ROLE(),
      retailer.address,
    );
    expect(hasRole).to.be.true;
  });
});
