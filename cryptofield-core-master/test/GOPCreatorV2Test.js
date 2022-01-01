const GOPCreatorV2 = artifacts.require("GOPCreatorV2");
const PrivGOP = artifacts.require('PrivateGOPCreatorV2')
const Core = artifacts.require("Core");
const HorseData = artifacts.require("HorseData");

contract("GOPCreatorV2", acc => {
  let privGOP, gop, core, horseData;
  let owner = acc[0];
  let receiver = acc[1];
  let amount = web3.utils.toWei("2", "ether");

  beforeEach("setup instances", async() => {
    core = await Core.new();
    await core.initialize(owner);

    privGOP = await PrivGOP.new();

    gop = await GOPCreatorV2.new(receiver, privGOP.address, core.address, acc[3], {
      from: owner
    })

    horseData = await HorseData.new();
    await horseData.initialize();

    await core.setGOPCreator(gop.address, {
      from: owner
    });
    await core.setHorseDataAddr(horseData.address, {
      from: owner
    });

    await gop.openBatch(1, {
      from: owner
    });

    await gop.createGOP(owner, "some hash", {
      from: owner,
      value: amount
    })
  })

  it("should get the state from old gop contract", async() => {
    // No horses were sold so this should have the default values
    let firstGen = await gop.horsesRemaining(1);
    let tenthGen = await gop.horsesRemaining(10);

    assert.equal(firstGen.toString(), "1000");
    assert.equal(tenthGen.toString(), "10000")
  })

  it("should buy a horse and decrease counter", async() => {
    await gop.createGOP(owner, "some hash", {
      from: owner,
      value: amount
    });

    let remaining = await gop.horsesRemaining(1);

    assert.equal(web3.utils.toBN(remaining)
      .toNumber(), 999);
  })

  it("should create correct horse based on open batch", async() => {
    await gop.openBatch(3, {
      from: owner
    });
    await gop.createGOP(owner, "some hash", {
      from: owner,
      value: amount
    });

    let data = await core.getHorseData(1);

    assert.equal(web3.utils.toBN(data[5])
      .toNumber(), 3);
    assert.equal(web3.utils.hexToUtf8(data[6]), "S");
  })

  it("should revert when no value is sent", async() => {
    try {
      await gop.createGOP(owner, "some hash");
      assert.fail("Expected revert not received");
    } catch(err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }

    let genotype = await core.getHorseData(1);
    assert.equal(web3.utils.toBN(genotype[5])
      .toNumber(), 0);
  })

  it("should transfer the paid amount to the receiver", async() => {
    let balance = await web3.eth.getBalance(receiver);

    // Batch open <1>
    await gop.createGOP(acc[2], "some hash", {
      from: acc[2],
      value: amount
    });

    let newBalance = await web3.eth.getBalance(receiver);

    assert.isTrue(newBalance > balance);
  })

  it("should create horse with specific data", async() => {
    let givenGender = web3.utils.stringToHex("Male");
    await gop.createCustomHorse(owner, "some hash", 3, givenGender, {
      from: owner
    });

    let baseValue = await core.getBaseValue(1);

    assert.isAtMost(web3.utils.toBN(baseValue)
      .toNumber(), 80);
    assert.isAtLeast(web3.utils.toBN(baseValue)
      .toNumber(), 76);

    let data = await core.getHorseData(1);

    assert.equal(data[0], "some hash");
    assert.equal(web3.utils.hexToUtf8(data[1]), "M");
    assert.equal(web3.utils.toBN(data[5])
      .toNumber(), 3);
    assert.equal(web3.utils.hexToUtf8(data[6]), "S");
    assert.equal(web3.utils.hexToUtf8(data[7]), "Colt");

    givenGender = web3.utils.stringToHex("Female");
    await gop.createCustomHorse(owner, "another hash", 6, givenGender, {
      from: owner
    });

    data = await core.getHorseData(2);

    assert.equal(data[0], "another hash");
    assert.equal(web3.utils.hexToUtf8(data[1]), "F");
    assert.equal(web3.utils.toBN(data[5])
      .toNumber(), 6);
    assert.equal(web3.utils.hexToUtf8(data[6]), "F"); // Finney
    assert.equal(web3.utils.hexToUtf8(data[7]), "Filly");
  })

  it("should create a random horse from the specefied genotype", async() => {
    await gop.createRandomHorseFor(owner, "508 hash", 8, {
      from: owner
    });

    let data = await core.getHorseData(1);

    assert.equal(web3.utils.toBN(data[5])
      .toNumber(), 8);
    assert.equal(web3.utils.hexToUtf8(data[6]), "B");
  })

  it("should mark a code as used", async() => {
    let id = web3.utils.toHex("xxx")

    await gop.markCodeAsUsed(id, {
      from: owner
    });

    // should revert because code is marked as used already.
    try {
      await gop.markCodeAsUsed(id, {
        from: owner
      });
      assert.fail("Expected revert not received");
    } catch(err) {
      assert.equal(err.reason, "Code has been used");
    }
  })

  it("should mark a code as unused", async() => {
    // should revert as code is not used yet
    let id = web3.utils.toHex("xxx")
    try {
      await gop.markCodeAsUnused(id, {
        from: owner
      });
      assert.fail("Expected revert not received");
    } catch(err) {
      assert.equal(err.reason, "Code has not been used");
    }
  })

})
