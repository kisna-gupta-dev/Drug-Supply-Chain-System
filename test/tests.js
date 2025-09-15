const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BasicMechanism", function () {
  let BasicMechanism, basicMechanism, drugSupplyChain;
  let owner, manufacturer, distributor, retailer, other;
  let priceFeed, escrow;

  beforeEach(async function () {
    [owner, manufacturer, distributor, retailer, other] =
      await ethers.getSigners();

    // Deploy Mock PriceFeed and Escrow Contracts
    const PriceFeed = await ethers.getContractFactory("MockV3Aggregator");
    priceFeed = await PriceFeed.deploy(18, 4358000);
    await priceFeed.waitForDeployment();
    console.log("--------------------------");

    const Escrow = await ethers.getContractFactory("Escrow");
    escrow = await Escrow.deploy();
    await escrow.waitForDeployment();
    console.log("--------------------------");

    const DrugSupplyChain = await ethers.getContractFactory("DrugSupplyChain");
    drugSupplyChain = await DrugSupplyChain.connect(owner).deploy(
      priceFeed.target,
      escrow.target,
    );
    await drugSupplyChain.waitForDeployment();
    console.log("--------------------------");

    // Deploy BasicMechanism Contract
    BasicMechanism = await ethers.getContractFactory("BasicMechanism");
    basicMechanism = await BasicMechanism.connect(owner).deploy(
      priceFeed.target,
      escrow.target,
    );
    await basicMechanism.waitForDeployment();
    console.log("--------------------------");

    // Grant roles
    const MANUFACTURER_ROLE = await basicMechanism.MANUFACTURER_ROLE();
    const DISTRIBUTOR_ROLE = await basicMechanism.DISTRIBUTOR_ROLE();
    const RETAILER_ROLE = await basicMechanism.RETAILER_ROLE();

    await basicMechanism
      .connect(owner)
      .grantRole(MANUFACTURER_ROLE, manufacturer.address);
    await basicMechanism
      .connect(owner)
      .grantRole(DISTRIBUTOR_ROLE, distributor.address);
    await basicMechanism
      .connect(owner)
      .grantRole(RETAILER_ROLE, retailer.address);
  });

  it("All addresses are valid addresses", async function () {
    expect(priceFeed.target).to.properAddress;
    expect(escrow.target).to.properAddress;
    expect(drugSupplyChain.target).to.properAddress;
    expect(basicMechanism.target).to.properAddress;
  });

  it("Should create a new batch", async function () {
    const expiry = Math.floor(Date.now() / 1000) + 86400; // 1 day ahead
    const price = 100;

    await expect(
      basicMechanism.connect(manufacturer).createBatch(
        manufacturer.address,
        expiry,
        price,
        ethers.ZeroAddress, // using 'other' as dummy IPFS hash
      ),
    ).to.emit(basicMechanism, "BatchCreated");
  });

  it("Should not create batch with invalid data", async function () {
    const expiry = Math.floor(Date.now() / 1000) - 86400; // already expired
    const price = 100;

    await expect(
      basicMechanism
        .connect(manufacturer)
        .createBatch(ethers.ZeroAddress, expiry, price, other.address),
    ).to.be.revertedWith("Manufacturer address cannot be zero");
  });

  it("Should allow distributor to buy a batch", async function () {
    const expiry = Math.floor(Date.now() / 1000) + 86400;
    const price = 100;
    let args;
    // Manufacturer creates batch
    const tx = await basicMechanism
      .connect(manufacturer)
      .createBatch(manufacturer.address, expiry, price, ethers.ZeroAddress);

    //IMPORTANT -> Listening for the evnt emitted from solidity
    //1. we get the transaction response
    //2. we get the receipt from that transaction
    //3. through that receipt we apply a filter for event and along with that passes the blocknumber for filtering
    //4. after we filters that we get the event and finally we can locate the args that we want from that event (in this case it was batchId)
    const receipt = await tx.wait();
    const events = await basicMechanism.queryFilter(
      "BatchCreated",
      receipt.blockNumber,
    );
    const event = events[0];
    const batchId = event.args[0];
    // Distributor buys batch
    await expect(
      basicMechanism.connect(distributor).buyBatchDistributor(batchId, 150, {
        value: price,
      }),
    ).to.emit(basicMechanism, "DistributerPurchased");
  });

  it("Should allow retailer to buy a batch", async function () {
    const expiry = Math.floor(Date.now() / 1000) + 86400;
    const price = 100;

    // Manufacturer creates batch
    const tx = await basicMechanism
      .connect(manufacturer)
      .createBatch(manufacturer.address, expiry, price, other.address);
    const receipt = await tx.wait();
    const events = await basicMechanism.queryFilter(
      "BatchCreated",
      receipt.blockNumber,
    );
    const event = events[0];
    const batchId = event.args[0];

    // Distributor buys batch
    await basicMechanism
      .connect(distributor)
      .buyBatchDistributor(batchId, 150, {
        value: price,
      });

    // Retailer buys batch
    await expect(
      basicMechanism
        .connect(retailer)
        .buyBatchRetailer(batchId, { value: 150 }),
    ).to.emit(basicMechanism, "RetailerPurchased");
  });

  // it("Should retrieve batch details", async function () {
  //   const expiry = Math.floor(Date.now() / 1000) + 86400;
  //   const price = ethers.utils.parseEther("1");

  //   const tx = await basicMechanism
  //     .connect(manufacturer)
  //     .createBatch(manufacturer.address, expiry, price, other.address);
  //   const receipt = await tx.wait();
  //   const event = receipt.events.find(
  //     (event) => event.event === "BatchCreated",
  //   );
  //   const batchId = event.args.batchId;

  //   const batch = await basicMechanism.getBatchDetails(batchId);
  //   expect(batch.manufacturer).to.equal(manufacturer.address);
  // });

  // it("Should return IPFS hash for batch", async function () {
  //   const expiry = Math.floor(Date.now() / 1000) + 86400;
  //   const price = ethers.utils.parseEther("1");

  //   const tx = await basicMechanism
  //     .connect(manufacturer)
  //     .createBatch(manufacturer.address, expiry, price, other.address);
  //   const receipt = await tx.wait();
  //   const event = receipt.events.find(
  //     (event) => event.event === "BatchCreated",
  //   );
  //   const batchId = event.args.batchId;

  //   const ipfsHash = await basicMechanism.getIpfsHash(batchId);
  //   expect(ipfsHash).to.equal(other.address);
  // });
});
