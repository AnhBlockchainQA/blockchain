const Core = artifacts.require("Core");
const GOPCreatorV2 = artifacts.require("GOPCreatorV2");
const PrivGOP = artifacts.require('PrivateGOPCreatorV2')
const HorseData = artifacts.require("HorseData");

contract("Token", acc => {
  let instance, privGOP, gop, hd;
  let owner = acc[1];
  let secondBuyer = acc[2];
  let amount = web3.utils.toWei("0.40", "ether");

  beforeEach("setup instances", async() => {
    instance = await Core.new();
    await instance.initialize(owner);

    privGOP = await PrivGOP.new();

    gop = await GOPCreatorV2.new(owner, privGOP.address, instance.address, acc[3], {
      from: owner
    })

    hd = await HorseData.new();
    await hd.initialize();

    await instance.setGOPCreator(gop.address, {
      from: owner
    })
    await instance.setHorseDataAddr(hd.address, {
      from: owner
    })

    await gop.openBatch(1, {
      from: owner
    });
    await gop.createGOP(owner, "male hash", {
      from: owner,
      value: amount
    });
  })

  it("should mint a new token with specified params", async() => {
    await gop.createGOP(owner, "male hash", {
      from: owner,
      value: amount
    });
    let tokenOwner = await instance.ownerOf(1);

    assert.equal(tokenOwner, owner);
  })

  it("should be able to transfer a token", async() => {
    // 'owner' has token 1.
    await gop.createGOP(owner, "male hash", {
      from: owner,
      value: amount
    });
    await instance.safeTransferFrom(owner, secondBuyer, 1, {
      from: owner
    })

    let newTokenOwner = await instance.ownerOf(1);

    assert.equal(secondBuyer, newTokenOwner);
  })

  it("should select the correct range of base value depending on the gen", async() => {
    await gop.createGOP(owner, "some hash", {
        from: owner,
        value: amount
      }) // 1

    let baseValue = await instance.getBaseValue(1)

    assert.isAtLeast(web3.utils.toBN(baseValue)
      .toNumber(), 95)
    assert.isAtMost(web3.utils.toBN(baseValue)
      .toNumber(), 99);

    await gop.openBatch(2, {
      from: owner
    })
    await gop.createGOP(owner, "some hash", {
        from: owner,
        value: amount
      }) // 2

    baseValue = await instance.getBaseValue(2);

    assert.isAtMost(web3.utils.toBN(baseValue)
      .toNumber(), 89);
    assert.isAtLeast(web3.utils.toBN(baseValue)
      .toNumber(), 80)
  })

  it("should only allow the admin to transfer a token without approval", async() => {
    await gop.createGOP(owner, "some hash", {
      from: owner,
      value: amount
    }); // 1
    let ownerOf = await instance.ownerOf(1);
    assert.equal(ownerOf, owner);

    let oldTotalSupply = await instance.totalSupply();
    assert.equal(oldTotalSupply.toString(), "2");

    await instance.adminTransferToken(1, acc[2], {
      from: owner
    });
    let newOwner = await instance.ownerOf(1);
    assert.equal(newOwner, acc[2])

    let newTotalSupply = await instance.totalSupply();
    assert.equal(oldTotalSupply.toString(), newTotalSupply.toString())
  })
})
