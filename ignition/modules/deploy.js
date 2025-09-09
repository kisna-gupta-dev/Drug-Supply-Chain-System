const { ethers } = require("hardhat");

async function main() {
  //   const { deployer } = ethers.getSigners(); This will not work because it returns an Promise of an array not an object
  const [deployer] = await ethers.getSigners(); //This will work because

  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Account balance:",
    (await ethers.provider.getBalance(deployer)).toString(),
  );

  const Escrow = await ethers.getContractFactory("Escrow");
  const escrow = await Escrow.deploy();
  const escrowaddress = await escrow.getAddress();
  console.log("Escrow deployed to:", await escrowaddress);

  console.log("----------------------------------------------------");
  const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
  const mockV3Aggregator = await MockV3Aggregator.deploy(18, 435800000000);
  const mockV3Aggregatoraddress = await mockV3Aggregator.getAddress();
  console.log("MockV3Aggregator deployed to:", mockV3Aggregatoraddress);

  console.log("----------------------------------------------------");
  console.log("Deploying DrugSupplyChain Contract....");
  const DrugSupplyChain = await ethers.getContractFactory("DrugSupplyChain");
  const drugSupplyChain = await DrugSupplyChain.deploy(
    mockV3Aggregatoraddress,
    await escrow.getAddress(),
  );
  console.log(
    "DrugSupplyChain deployed to:",
    await drugSupplyChain.getAddress(),
  );

  console.log("----------------------------------------------------");
  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Account balance:",
    (await ethers.provider.getBalance(deployer)).toString(),
  );

  console.log("----------------------------------------------------");
  console.log("Deploying BasicMechanism Contract....");
  const BasicMechanism = await ethers.getContractFactory("BasicMechanism");
  const BasicMechanismContract = await BasicMechanism.deploy(
    mockV3Aggregatoraddress,
    escrowaddress,
  );
  console.log(
    "BasicMechanism Contract deployed to:",
    await BasicMechanismContract.getAddress(),
  );

  console.log("----------------------------------------------------");
  console.log("Deploying HandlingAddresses Contract....");
  const HandlingAddresses =
    await ethers.getContractFactory("HandlingAddresses");
  const HandlingAddressesContract = await HandlingAddresses.deploy(
    mockV3Aggregatoraddress,
    escrowaddress,
  );
  console.log(
    "HandlingAddresses Contract deployed to:",
    await HandlingAddressesContract.getAddress(),
  );

  console.log("----------------------------------------------------");
  console.log("Deploying ResellMechanism Contract....");
  const ResellMechanism = await ethers.getContractFactory("ResellMechanism");
  const ResellMechanismContract = await ResellMechanism.deploy(
    mockV3Aggregatoraddress,
    escrowaddress,
  );
  console.log(
    "ResellMechanism Contract deployed to:",
    await ResellMechanismContract.getAddress(),
  );

  console.log("----------------------------------------------------");
  console.log("Deploying HandlingRequests Contract....");
  const HandlingRequests = await ethers.getConytractFactory("HandlingRequests");
  const HandlingRequestsContract = await HandlingRequests.deploy(
    mockV3Aggregatoraddress,
    escrowaddress,
  );
  console.log(
    "HandlingRequests Contract deployed to:",
    await HandlingRequestsContract.getAddress(),
  );

  console.log("----------------------------------------------------");
  console.log("Deploying Upkeep Automation Contract....");
  const UpKeepAutomation = await ethers.getContractFactory("upKeep");
  const UpKeepAutomationContract = await UpKeepAutomation.deploy(
    mockV3Aggregatoraddress,
    escrowaddress,
  );
  console.log(
    "Upkeep Automation Contract deployed to:",
    await UpKeepAutomationContract.getAddress(),
  );

  console.log("----------------------------------------------------");
  console.log("All Contracts Deployed Successfully");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
