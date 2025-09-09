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
  console.log("Escrow deployed to:", await escrow.getAddress());



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
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
