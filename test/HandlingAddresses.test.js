const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("HandlingAddresses", async function () {
  let admin, manufacturer, distributor, retailer, other;
  let HandlingAddresses, handlingAddresses;
  beforeEach(async function () {
    [admin, manufacturer, distributor, retailer, other] =
      await ethers.getSigners();

    HandlingAddresses = await ethers.getContractFactory("HandlingAddresses");
    handlingAddresses = await HandlingAddresses.connect(admin).deploy();
    await handlingAddresses.waitForDeployment();
  });

  describe("Role Management", async function () {
    it("should add a manufacturer", async function () {
      expect(
        await handlingAddresses
          .connect(admin)
          .addManufacturer(manufacturer.address),
      )
        .to.emit(handlingAddresses, "RoleGranted")
        .withArgs(
          await handlingAddresses.MANUFACTURER_ROLE,
          manufacturer.address,
          admin.address,
        );

      expect(
        await handlingAddresses.hasRole(
          handlingAddresses.MANUFACTURER_ROLE(),
          manufacturer.address,
        ),
      ).to.be.true;
    });

    it("should not allow non-admin to add manufacturer", async function () {
      await expect(
        handlingAddresses
          .connect(manufacturer)
          .addManufacturer(manufacturer.address),
      )
        .to.be.revertedWithCustomError(
          handlingAddresses,
          "AccessControlUnauthorizedAccount",
        )
        .withArgs(
          manufacturer.address,
          await handlingAddresses.DEFAULT_ADMIN_ROLE(),
        );
    });

    it("should not add an existin manufacturer", async function () {
      expect(
        await handlingAddresses
          .connect(admin)
          .addManufacturer(manufacturer.address),
      ).not.to.be.reverted;

      await expect(
        handlingAddresses.connect(admin).addManufacturer(manufacturer.address),
      )
        .to.be.revertedWithCustomError(
          handlingAddresses,
          "AddressAlreadyExists",
        )
        .withArgs("Manufacturer", manufacturer.address);
    });

    it("should add a distributor and a retailer", async function () {
      expect(
        await handlingAddresses
          .connect(admin)
          .addDistributor(distributor.address),
      ).not.to.be.reverted;

      expect(
        await handlingAddresses.connect(admin).addRetailer(retailer.address),
      ).not.to.be.reverted;

      expect(
        await handlingAddresses.hasRole(
          await handlingAddresses.DISTRIBUTOR_ROLE(),
          distributor.address,
        ),
      ).to.be.true;

      expect(
        await handlingAddresses.hasRole(
          await handlingAddresses.RETAILER_ROLE(),
          retailer.address,
        ),
      ).to.be.true;
    });
  });

  describe("Freezin and Unfreezing", async function () {
    it("should freeze and revoke roles", async function () {
      await handlingAddresses
        .connect(admin)
        .addManufacturer(manufacturer.address);

      await expect(
        handlingAddresses.connect(admin).frozeAddress(manufacturer.address),
      )
        .to.emit(handlingAddresses, "AddressFrozen")
        .withArgs(manufacturer.address);

      expect(
        await handlingAddresses.hasRole(
          await handlingAddresses.MANUFACTURER_ROLE(),
          manufacturer.address,
        ),
      ).to.be.false;

      expect(await handlingAddresses.isFrozen(manufacturer.address)).to.be.true;
    });

    it("should unfreeze address", async function () {
      await handlingAddresses
        .connect(admin)
        .addManufacturer(manufacturer.address);
      await handlingAddresses.connect(admin).frozeAddress(manufacturer.address);

      expect(
        await handlingAddresses
          .connect(admin)
          .unfreezeAddress(manufacturer.address),
      ).not.to.be.reverted;

      expect(await handlingAddresses.isFrozen(manufacturer.address)).to.be
        .false;
    });

    it("should not freeze zero address", async function () {
      await expect(
        handlingAddresses.connect(admin).frozeAddress(ethers.ZeroAddress),
      ).to.be.revertedWith("Cannot freeze the zero address");
    });

    it("should not unfreeze zero address", async function () {
      await expect(
        handlingAddresses.connect(admin).unfreezeAddress(ethers.ZeroAddress),
      ).to.be.revertedWith("Cannot unfreeze the zero address");
    });
  });

  describe("Revoking Roles", async function () {
    it("should allow admin to revoke manufacturer", async function () {
      await handlingAddresses
        .connect(admin)
        .addManufacturer(manufacturer.address);

      expect(
        await handlingAddresses
          .connect(admin)
          .removeManufacturer(manufacturer.address),
      ).not.to.be.reverted;

      expect(
        await handlingAddresses.hasRole(
          await handlingAddresses.MANUFACTURER_ROLE(),
          manufacturer.address,
        ),
      ).to.be.false;
    });

    it("should revoke roles for distributor and retailer", async function () {
      await handlingAddresses
        .connect(admin)
        .addDistributor(distributor.address);
      await handlingAddresses.connect(admin).addRetailer(retailer.address);

      expect(
        await handlingAddresses
          .connect(admin)
          .removeDistributor(distributor.address),
      ).not.to.be.reverted;

      expect(
        await handlingAddresses.connect(admin).removeRetailer(retailer.address),
      ).not.to.be.reverted;

      expect(
        await handlingAddresses
          .connect(admin)
          .hasRole(
            await handlingAddresses.DISTRIBUTOR_ROLE(),
            distributor.address,
          ),
      ).to.be.false;

      expect(
        await handlingAddresses
          .connect(admin)
          .hasRole(await handlingAddresses.RETAILER_ROLE(), retailer.address),
      ).to.be.false;
    });

    it("should not allow non-admin to revoke roles", async function () {
      await handlingAddresses
        .connect(admin)
        .addManufacturer(manufacturer.address);
      await expect(
        handlingAddresses
          .connect(manufacturer)
          .removeManufacturer(manufacturer.address),
      )
        .to.be.revertedWithCustomError(
          handlingAddresses,
          "AccessControlUnauthorizedAccount",
        )
        .withArgs(
          manufacturer.address,
          await handlingAddresses.DEFAULT_ADMIN_ROLE(),
        );
    });
  });
});
