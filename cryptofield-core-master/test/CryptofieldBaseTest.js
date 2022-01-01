const Core = artifacts.require("Core");
const GOPCreator = artifacts.require("GOPCreatorV2");
const PrivGOP = artifacts.require('PrivateGOPCreatorV2')
const HorseData = artifacts.require("HorseData");

contract("CryptofieldBaseContract", accounts => {
  let core, privGOP, gop, hd, project;
  let hash = "QmTsG4gGyRYXtBeTY7wqcyoksUp9QUpjzoYNdz8Y91GwoQ";
  let owner = accounts[1];
  let amount = web3.utils.toWei("0.5", "ether");

  before("setup instances", async() => {
    core = await Core.new();
    await core.initialize(owner);

    privGOP = await PrivGOP.new();

    gop = await GOPCreator.new(owner, privGOP.address, core.address, accounts[3], {
      from: owner
    })

    hd = await HorseData.new();
    await hd.initialize();

    await core.setGOPCreator(gop.address, {
      from: owner
    });
    await core.setHorseDataAddr(hd.address, {
      from: owner
    });

    await gop.openBatch(1, {
      from: owner
    });
  })


  it("should be able to buy a horse", async() => {
    await gop.createGOP(owner, hash, {
      from: owner,
      value: amount
    }); // 0

    let horseHash = await core.getHorseData(0);

    assert.equal(horseHash[0], hash);
  })

  it("should create correct genotype based on number of sale", async() => {
    // If we get the first one, we should have genotype 1.
    let genotype = await core.getHorseData(0);
    assert.equal(web3.utils.toBN(genotype[5])
      .toNumber(), 1);

    for(let i = 0; i <= 305; i++) {
      if(i === 100) {
        await gop.openBatch(2, {
          from: owner
        });
      } else if(i === 299) {
        await gop.openBatch(3, {
          from: owner
        });
      }

      await gop.createGOP(accounts[5], "random hash", {
        from: accounts[5],
        value: amount
      });
    }

    genotype = await core.getHorseData(100);
    assert.equal(web3.utils.toBN(genotype[5])
      .toNumber(), 1);

    let genotype2 = await core.getHorseData(120);
    assert.equal(web3.utils.toBN(genotype2[5])
      .toNumber(), 2);
  })

  it("should create the correct bloodline for a horse", async() => {
    // We're using horses from the above test.
    let bloodline = await core.getHorseData(88);
    assert.equal(web3.utils.hexToUtf8(bloodline[6]), "N");

    bloodline = await core.getHorseData(150);
    assert.equal(web3.utils.hexToUtf8(bloodline[6]), "N");

    bloodline = await core.getHorseData(302);
    assert.equal(web3.utils.hexToUtf8(bloodline[6]), "S");
  })
})
