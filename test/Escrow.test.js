// describe("Escrow", async function () {
//   it("escrow deployed successfully", async function () {
//     const { escrowaddress } = await loadFixture(setupFixture);
//     expect(ethers.isAddress(escrowaddress)).to.be.true;
//   });
//   it("escrow has the correct owner", async function () {
//     const { escrow, deployer } = await loadFixture(setupFixture);
//     const owner = await escrow.owner();
//     expect(owner).to.equal(deployer.address);
//   });
// });
