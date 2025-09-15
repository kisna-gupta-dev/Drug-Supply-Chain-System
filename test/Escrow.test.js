const { ethers } = require("hardhat");
const { expect } = require("chai");
describe("Escrow", async function () {
  let escrow;
  let owner, from, to;
  beforeEach(async function () {
    [owner, from, to] = await ethers.getSigners();

    const Escrow = await ethers.getContractFactory("Escrow");
    escrow = await Escrow.connect(owner).deploy();
    await escrow.waitForDeployment();
  });
  it("escrow deployed successfully", async function () {
    expect(escrow.target).to.be.properAddress;
  });
  it("escrow has the correct owner", async function () {
    const ownerInContract = await escrow.owner();
    expect(ownerInContract).to.equal(owner.address);
  });
  it("shoould fail if payer is zero", async function () {
    await expect(
      escrow.connect(from).buy(ethers.ZeroAddress, to.address, { value: 100 }),
    ).to.be.revertedWith("Payer address cannot be zero");
  });
  it("should fail if payee address is zero", async function () {
    await expect(
      escrow
        .connect(from)
        .buy(from.address, ethers.ZeroAddress, { value: 100 }),
    ).to.be.revertedWith("Payee address cannot be zero");
  });
  it("should fail if payment is less than or equal to zero", async function () {
    await expect(
      escrow.connect(from).buy(from.address, to.address, { value: 0 }),
    ).to.be.revertedWith("Insufficient payment sent");
  });
  it("should fail if payee address is zero", async function () {
    await expect(
      escrow.connect(to).release(ethers.ZeroAddress, 0),
    ).to.be.revertedWith("Payee address cannot be zero");
  });
  it("should release funds to payee", async function () {
    const initialBalance = BigInt(
      await ethers.provider.getBalance(from.address),
    );
    const amount = ethers.parseEther("1");
    const tx = await escrow
      .connect(from)
      .buy(from.address, to.address, { value: amount });
    const receipt = await tx.wait();
    let amount2 = BigInt(receipt.gasUsed) * BigInt(receipt.gasPrice);

    const tx2 = await escrow
      .connect(owner)
      .release(to.address, amount, { value: amount });
    await expect(tx2).to.changeEtherBalance(to.address, amount);

    const finalBalance = BigInt(await ethers.provider.getBalance(from.address));
    expect(initialBalance - finalBalance).to.equal(amount + amount2);
  });
});
