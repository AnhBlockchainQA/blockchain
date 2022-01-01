const GOPCreatorV3 = artifacts.require("GOPCreatorV3");
const Core = artifacts.require("Core");
const HorseData = artifacts.require("HorseData");

contract("GOPCreatorV3", (acc) => {
  let gop, core, horseData;
  let owner = acc[0];
  let receiver = acc[1];
  let blockchainBrain = acc[3];

  beforeEach("setup instances", async () => {
    horseData = await HorseData.new();
    core = await Core.new(horseData.address);
    gop = await GOPCreatorV3.new(receiver, core.address, blockchainBrain);

    // This will give GOPCreator the ability to call certain functions from Core
    await core.grantRole(web3.utils.toHex("core_contracts"), gop.address);
    await gop.grantRole(web3.utils.toHex("gop_owners"), owner);

    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].forEach(
      async (x) =>
        await gop.setHorsesRemaining(x, 1000, { from: blockchainBrain })
    );

    await gop.createCustomHorse(
      owner,
      1,
      web3.utils.toHex("Male"),
      web3.utils.toHex("FirstName"),
      web3.utils.toHex("Black"),
      { from: blockchainBrain }
    );
  });

  describe("creating horse", async () => {
    it("should buy a horse and decrease counter", async () => {
      await gop.createCustomHorse(
        owner,
        1,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Second"),
        web3.utils.toHex("Black"),
        { from: blockchainBrain }
      );

      let remaining = await gop.horsesRemaining(1);

      // 8 remaining because we create one on the setup
      assert.equal(web3.utils.toBN(remaining).toNumber(), 998);
    });

    it("should create horse with specific data", async () => {
      let givenGender = web3.utils.stringToHex("Male");
      await gop.createCustomHorse(
        owner,
        3,
        givenGender,
        web3.utils.toHex("Second"),
        web3.utils.toHex("Black"),
        { from: blockchainBrain }
      );

      let baseValue = await core.getBaseValue(1);

      assert.isAtMost(web3.utils.toBN(baseValue).toNumber(), 80);
      assert.isAtLeast(web3.utils.toBN(baseValue).toNumber(), 76);

      let data = await core.getHorseData(1);

      assert.equal(web3.utils.hexToUtf8(data[0]), "M");
      assert.equal(web3.utils.toBN(data[3]).toNumber(), 3);
      assert.equal(web3.utils.hexToUtf8(data[4]), "S");
      assert.equal(web3.utils.hexToUtf8(data[5]), "Colt");

      givenGender = web3.utils.stringToHex("Female");
      await gop.createCustomHorse(
        owner,
        6,
        givenGender,
        web3.utils.toHex("Third"),
        web3.utils.toHex("Black"),
        { from: blockchainBrain }
      );

      data = await core.getHorseData(2);

      assert.equal(web3.utils.hexToUtf8(data[0]), "F");
      assert.equal(web3.utils.toBN(data[3]).toNumber(), 6);
      assert.equal(web3.utils.hexToUtf8(data[4]), "F"); // Finney
      assert.equal(web3.utils.hexToUtf8(data[5]), "Filly");
    });

    it("should revert if there are no more horses for a genotype", async () => {
      await gop.setHorsesRemaining(1, 0, { from: blockchainBrain });

      try {
        await gop.createCustomHorse(
          owner,
          1,
          web3.utils.toHex("Female"),
          web3.utils.toHex("Second"),
          web3.utils.toHex("Black"),
          { from: blockchainBrain }
        );

        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "GOP: Limit for genotype reached");
      }
    });
  });

  describe("horse codes", async () => {
    it("should mark a code as used", async () => {
      let id = web3.utils.toHex("xxx");

      await gop.markCodeAsUsed(id, {
        from: owner,
      });

      // should revert because code is marked as used already.
      try {
        await gop.markCodeAsUsed(id, {
          from: owner,
        });
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "GOP: Code has been used");
      }
    });

    it("should mark a code as unused", async () => {
      // should revert as code is not used yet
      let id = web3.utils.toHex("xxx");
      try {
        await gop.markCodeAsUnused(id, {
          from: owner,
        });
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "GOP: Code has not been used");
      }
    });
  });
});
