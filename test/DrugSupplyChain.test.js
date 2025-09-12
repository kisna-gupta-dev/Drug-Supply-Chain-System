// const { expect } = require("chai");
// const { ethers, assert } = require("hardhat");
// const {
//   loadFixture,
// } = require("@nomicfoundation/hardhat-network-helpers");
// const { setupFixture } = require("./tests.js");

// describe("DrugSupplyChain", function () {
//   it("drugSupplyChain deployed successfully", async function () {
//     const { drugSupplyChainAddress } = await loadFixture(setupFixture);
//     expect(ethers.isAddress(drugSupplyChainAddress)).to.be.true;
//   });
//   it("drugSupplyChain has the correct owner", async function () {
//     const { drugSupplyChain, deployer } = await loadFixture(setupFixture);
//     const owner = await drugSupplyChain.owner();
//     expect(owner).to.equal(deployer.address);
//   });
//   it("escrow address is correct", async function () {
//     const { drugSupplyChain, escrowaddress } = await loadFixture(setupFixture);
//     const escrowAddr = await drugSupplyChain.escrowContract();
//     expect(escrowAddr).to.equal(escrowaddress);
//   });
//   it("Default admin role is assigned to deployer", async function () {
//     const { drugSupplyChain, deployer } = await loadFixture(setupFixture);
//     const hasRole = await drugSupplyChain.hasRole(
//       await drugSupplyChain.DEFAULT_ADMIN_ROLE(),
//       deployer.address,
//     );
//     expect(hasRole).to.be.true;
//   });
//   it("Manufacturer role is assigned to addr1", async function () {
//     const { drugSupplyChain, addr1 } = await loadFixture(setupFixture);
//     const hasRole = await drugSupplyChain.hasRole(
//       await drugSupplyChain.MANUFACTURER_ROLE(),
//       addr1.address,
//     );
//     expect(hasRole).to.be.true;
//   });
//   it("Distributor role is assigned to addr2", async function () {
//     const { drugSupplyChain, addr2 } = await loadFixture(setupFixture);
//     const hasRole = await drugSupplyChain.hasRole(
//       await drugSupplyChain.DISTRIBUTOR_ROLE(),
//       addr2.address,
//     );
//     expect(hasRole).to.be.true;
//   });
//   it("Retailer role is assigned to addr3", async function () {
//     const { drugSupplyChain, addr3 } = await loadFixture(setupFixture);
//     const hasRole = await drugSupplyChain.hasRole(
//       await drugSupplyChain.RETAILER_ROLE(),
//       addr3.address,
//     );
//     expect(hasRole).to.be.true;
//   });
// });
