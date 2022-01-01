const Core = artifacts.require("Core");
const HorseData = artifacts.require("HorseData");
const Breeding = artifacts.require("Breeding");
const BreedingProxy = artifacts.require("BreedingProxy");
const BreedingProxyAdmin = artifacts.require("BreedingProxyAdmin");
const StudService = artifacts.require("StudServiceV5");
const BreedTypes = artifacts.require("BreedTypes");
const ERC20Test = artifacts.require("ERC20Test");
const ganache = require("ganache-core");

import {
  funcFromABI,
  signTxData,
  getTypedData,
  getRsvFromSig,
  metaTxsAccounts,
} from "../../utils";

contract("Breeding", (acc) => {
  const maxWETH = web3.utils.toWei("1000", "ether");

  let core,
    breedTypes,
    breedingLogic,
    breedingProxy,
    breedingProxyAdmin,
    breeding,
    studService,
    horseData,
    erc20,
    chainId;

  let owner = acc[0],
    poolAddress = acc[1],
    blockchainBrain = acc[2],
    amount = web3.utils.toWei("0.2", "ether"),
    priceyAmount = web3.utils.toWei("1", "ether");

  beforeEach("deploy instances", async () => {
    horseData = await HorseData.new();
    core = await Core.new(horseData.address);
    chainId = await web3.eth.net.getId();

    breedTypes = await BreedTypes.new();

    studService = await StudService.new(
      core.address,
      horseData.address,
      breedTypes.address
    );

    erc20 = await ERC20Test.new(web3.utils.toWei("100", "ether"));

    // Deploys Breeding Logic instance
    breedingLogic = await Breeding.new();

    // Deploys Breeding Admin to be used as admin of BreedingProxy
    breedingProxyAdmin = await BreedingProxyAdmin.new();

    // Deploys proxy instance
    breedingProxy = await BreedingProxy.new(
      breedingLogic.address,
      breedingProxyAdmin.address
    );

    breeding = await Breeding.at(breedingProxy.address);
  });

  beforeEach("setup initial state of instances", async () => {
    await breeding.setDomainSeparator("ZED Breeding", "1", chainId);

    await studService.grantRole(web3.utils.toHex("stud_owners"), owner);

    await core.grantRole(web3.utils.toHex("core_contracts"), owner);

    // We cannot interact with ID 0
    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Male"),
      web3.utils.toHex("FirstName"),
      web3.utils.toHex("Black")
    );

    await breedTypes.grantRole(web3.utils.toHex("breed_types_owners"), owner);

    await breeding.initialize(
      core.address,
      studService.address,
      breedTypes.address,
      erc20.address,
      poolAddress,
      acc[4]
    );

    await breedTypes.grantRole(
      web3.utils.toHex("breed_types_contracts"),
      breeding.address
    );

    // Core need to grant CORE_CONTRACTS_ROLE and CORE_OWNERS_ROLE for Breeding to able to invoke method Core.mintOffspring
    await core.grantRole(web3.utils.toHex("core_contracts"), breeding.address);
    await core.grantRole(web3.utils.toHex("core_owners"), breeding.address);

    // 1
    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Female"),
      web3.utils.toHex("Truc"),
      web3.utils.toHex("violet")
    );

    // 2
    await core.mintCustomHorse(
      acc[2],
      4,
      web3.utils.toHex("Male"),
      web3.utils.toHex("Trung"),
      web3.utils.toHex("blue")
    );

    await studService.putInStud(2, amount, 86400);

    await erc20.transfer(acc[2], amount);
    await erc20.transfer(acc[5], amount);
    await erc20.approve(breeding.address, maxWETH, {
      from: acc[2],
    });
    await erc20.approve(breeding.address, maxWETH, {
      from: acc[5],
    });
    await erc20.approve(breeding.address, maxWETH);

    // Female ID 1 and Male ID 2
  });

  describe("initial proxy validation", async () => {
    it("should make deployer of contract admin of breeding owners", async () => {
      const isDeployer = await breeding.hasRole(
        web3.utils.toHex("breeding_owners_admin"),
        owner
      );

      assert.isTrue(isDeployer);
    });

    it("should set upgrade admin correctly", async () => {
      // only admin can call this function so if it goes through it's ok
      await breedingProxyAdmin.getProxyImplementation(breedingProxy.address);
    });

    it("should upgrade to new implementation", async () => {
      assert.equal(
        await breedingProxyAdmin.getProxyImplementation(breedingProxy.address),
        breedingLogic.address
      );

      const newLogic = await Breeding.new();
      await breedingProxyAdmin.upgrade(breedingProxy.address, newLogic.address);

      assert.equal(
        await breedingProxyAdmin.getProxyImplementation(breedingProxy.address),
        newLogic.address
      );
    });

    it("should revert when calling initialize() after upgrading", async () => {
      const newLogic = await Breeding.new();
      await breedingProxyAdmin.upgrade(breedingProxy.address, newLogic.address);

      try {
        await breeding.initialize(
          core.address,
          studService.address,
          breedTypes.address,
          erc20.address,
          poolAddress,
          acc[2]
        );

        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(
          err.reason,
          "Initializable: contract is already initialized"
        );
      }
    });

    it("should hold state after upgrading", async () => {
      assert.isFalse(
        await breeding.hasRole(
          web3.utils.toHex("breeding_owners_admin"),
          blockchainBrain
        )
      );

      await breeding.grantRoleAdmin(
        web3.utils.toHex("breeding_owners_admin"),
        blockchainBrain
      );

      assert.isTrue(
        await breeding.hasRole(
          web3.utils.toHex("breeding_owners_admin"),
          blockchainBrain
        )
      );

      const newLogic = await Breeding.new();
      await breedingProxyAdmin.upgrade(breedingProxy.address, newLogic.address);

      assert.isTrue(
        await breeding.hasRole(
          web3.utils.toHex("breeding_owners_admin"),
          blockchainBrain
        )
      );
    });
  });

  describe("mix", async () => {
    it("should mix two horses", async () => {
      assert.isFalse(await core.tokenExists(3));

      await breeding.mix(2, 1, web3.utils.toHex("blueviolet"), amount);

      assert.isTrue(await core.tokenExists(3));

      let firstOffspringStats = await breeding.getHorseOffspringStats(1);
      let secondOffspringStats = await breeding.getHorseOffspringStats(2);

      assert.equal(web3.utils.toBN(firstOffspringStats).toNumber(), 1);
      assert.equal(web3.utils.toBN(secondOffspringStats).toNumber(), 1);

      // Ensure the owner is the owner of the female horse
      assert.equal(await core.ownerOf(3), owner);
    });

    it("should create a base value for the offspring", async () => {
      await breeding.mix(2, 1, web3.utils.toHex("blueviolet"), amount);

      let baseValue = await core.getBaseValue(3);
      assert.notEqual(web3.utils.toBN(baseValue).toNumber(), 0);

      // The parents of the third horse are horses from the first Gen, they have high base value
      // so offspring's base value should be at least 40.
      // This is a bit tricky because those numbers are random so we need to make assumptions about the base value.
      assert.isAbove(web3.utils.toBN(baseValue).toNumber(), 39);
    });

    it("should return the correct genotype for a given horse", async () => {
      await breeding.mix(2, 1, web3.utils.toHex("blueviolet"), amount);

      let genotype = await core.getHorseData(3);
      assert.equal(web3.utils.toBN(genotype[3]).toNumber(), 8);
    });

    it("should revert when mixing two offsprings from the same parents", async () => {
      let maleOffspring = await createOffspring(2, 1, "blue", owner, "M");

      let femaleOffspring = await createOffspring(2, 1, "yellow", owner, "F");

      await studService.putInStud(maleOffspring, amount, 1000);

      try {
        await breeding.mix(
          maleOffspring,
          femaleOffspring,
          web3.utils.toHex("colorNew"),
          amount
        );
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Breeding: horses are brothers");
      }
    });

    it("should revert when mixing an offspring with a parent", async () => {
      let femaleOffspring = await createOffspring(
        2,
        1,
        "colorFemale",
        owner,
        "F"
      );

      try {
        await breeding.mix(
          2,
          femaleOffspring,
          web3.utils.toHex("colorNew"),
          amount
        );
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Breeding: horses are directly related");
      }
    });

    it("should revert when first horse is not male", async () => {
      // Mixing the two horses from the same parents (5 and 6)
      try {
        await breeding.mix(1, 1, web3.utils.toHex("colorNew"), amount);
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(
          err.reason,
          "Breeding: expected male horse but received female"
        );
      }
    });

    it("should revert when the second parameter isn't a female horse", async () => {
      await core.mintCustomHorse(
        acc[2],
        4,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Trung2"),
        web3.utils.toHex("blue")
      );

      // Mixing the two horses from the same parents (5 and 6)
      try {
        await breeding.mix(2, 3, web3.utils.toHex("colorNew"), amount);
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(
          err.reason,
          "Breeding: expected female horse but received male"
        );
      }
    });

    it("should revert when mixing with ancestors", async () => {
      // Ancestors have a limit until grandparents, that would be two ancestors lines.
      // We'll go for Paternal grandparents
      // We'll use new horses for this.

      /*
             G     -      G
          |F - M   -   F - M|
            ||     -    ||
          S -- S   -  S -- S

          Family tree... sort of, we want to reach S and mate one of S with a G
      */

      // * Grandparents are the ones we created in the setup (ID 1 and 2)

      // Female horse 2
      await core.mintCustomHorse(
        owner,
        4,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Truc22"),
        web3.utils.toHex("violet")
      );

      // Male horse 2
      const male2Id = 4;
      await core.mintCustomHorse(
        owner,
        4,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Trung2"),
        web3.utils.toHex("blue")
      );

      await studService.putInStud(male2Id, amount, 100);

      let firstOffspringMale = await createOffspring(
        2,
        1,
        "offspring",
        owner,
        "M"
      );

      await studService.putInStud(firstOffspringMale, amount, 100);

      await core.mintCustomHorse(
        owner,
        4,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Trung3"),
        web3.utils.toHex("blue")
      ); // firstOffspringMale + 1

      // parents firstOffspringMale, firstOffspringMale + 1 / grandparents 2, 1.
      let secondOffspringMale = await createOffspring(
        firstOffspringMale,
        Number(firstOffspringMale) + 1,
        "offspring",
        owner,
        "M"
      );

      await studService.putInStud(secondOffspringMale, amount, 1);

      await core.mintCustomHorse(
        owner,
        4,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Trung4"),
        web3.utils.toHex("blue")
      ); // secondOffspringMale + 1

      await core.mintCustomHorse(
        owner,
        4,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Trung5"),
        web3.utils.toHex("blue")
      ); // secondOffspringMale + 2

      // parents firstOffspringMale, secondOffspringMale - grandparents 2, 1.
      await createOffspring(
        firstOffspringMale,
        Number(secondOffspringMale) + 2,
        "offspring",
        owner,
        "M"
      );

      // Trying to mate 12 with 9 should revert.
      try {
        await breeding.mix(
          secondOffspringMale,
          1,
          web3.utils.toHex("color"),
          amount
        );
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Breeding: horse is grandchild");
      }
    });

    it("should send part of the reserve amount to the owner of the horse when mixing", async () => {
      let preBalance = web3.utils.toWei(await web3.eth.getBalance(acc[2]));

      await core.mintCustomHorse(
        acc[2],
        4,
        web3.utils.toHex("Female"),
        web3.utils.toHex("ThirdName"),
        web3.utils.toHex("Black")
      );

      await breeding.mix(2, 3, web3.utils.toHex("colorNew"), amount, {
        from: acc[2],
        value: priceyAmount,
      });

      let currBalance = web3.utils.toWei(await web3.eth.getBalance(acc[2]));

      // Since the owner of the horse is
      assert.isTrue(Number(preBalance) > Number(currBalance));
    });

    it("should select the correct bloodline based in parents", async () => {
      await breeding.mix(2, 1, web3.utils.toHex("colorNew"), amount);

      let data = await core.getHorseData(3); // Nakamoto + Nakamoto = Nakamoto

      assert.equal(web3.utils.hexToUtf8(data[4]), "S");

      const cycles = 10;
      for (let i = 3; i <= cycles; i++) {
        await core.mintCustomHorse(
          acc[5],
          4,
          web3.utils.toHex("Female"),
          web3.utils.toHex(`Trung${i}`),
          web3.utils.toHex("blue")
        );
      }

      const offspringId = await core.nextTokenId();
      await breeding.mix(2, cycles, web3.utils.toHex("colorNew"), amount, {
        from: acc[5],
      });

      data = await core.getHorseData(offspringId);

      assert.equal(web3.utils.hexToUtf8(data[4]), "S");
    });

    // BreedTypes test
    it("should get breed type from parents", async () => {
      // Male horse
      const maleId = await core.nextTokenId();
      await core.mintCustomHorse(
        owner,
        4,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Trung1111"),
        web3.utils.toHex("blue")
      );
      const maleIdExist = await core.tokenExists(maleId);
      assert.equal(maleIdExist, true);

      // Female horse
      const femaleId = await core.nextTokenId();
      await core.mintCustomHorse(
        owner,
        4,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Truc2222"),
        web3.utils.toHex("violet")
      );
      const femaleIdExist = await core.tokenExists(femaleId);
      assert.equal(femaleIdExist, true);

      // Put a male horse into stud
      await studService.putInStud(maleId, amount, 1);

      const offspringId = await core.nextTokenId();
      await breeding.mix(
        maleId,
        femaleId,
        web3.utils.toHex("blueviolet"),
        amount
      );

      const offspringIdExist = await core.tokenExists(offspringId);
      assert.equal(offspringIdExist, true);

      // Parents are Genesis so we should have a Legendary
      let breedType = await breedTypes.getBreedType(offspringId);

      assert.equal(web3.utils.toUtf8(breedType), "legendary");
    });
  });

  describe("migrateData", async () => {
    it("should migrate well", async () => {
      const breedingData = { 0: ["1", "2"], 1: [], 2: "0" };
      const parents = breedingData[0];

      const offsprings = breedingData[1];
      const offspringCounter = 0;

      const fatherParents = [0, 1];
      const motherParents = [10, 11];

      const offspringBreedType = web3.utils.toHex("type");
      const offspringId = 14;

      await breeding.grantRole(
        web3.utils.toHex("breeding_owners"),
        blockchainBrain
      );

      await breeding.migrateData(
        offspringId,
        parents,
        offsprings,
        offspringCounter,
        fatherParents,
        motherParents,
        offspringBreedType,
        { from: blockchainBrain }
      );

      let isHorseMigrated = await breeding.isHorseAlreadyMigrated(offspringId);
      assert.isTrue(isHorseMigrated);

      // Must failed if migrate again
      try {
        await breeding.migrateData(
          offspringId,
          parents,
          offsprings,
          offspringCounter,
          fatherParents,
          motherParents,
          offspringBreedType,
          { from: blockchainBrain }
        );

        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Breeding: horse has been migrated already");
      }
    });
  });

  describe("pausable", async () => {
    it("can only be paused by accounts with correct role", async () => {
      await breeding.pause();
      await breeding.unpause();

      try {
        await breeding.pause({ from: acc[1] });
        assert.faile("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Breeding: unauthorized owner admin");
      }
    });

    it("should revert if contract is paused", async () => {
      await breeding.pause();

      try {
        await breeding.mix(2, 1, web3.utils.toHex("blueviolet"), amount);
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Pausable: paused");
      }
    });
  });

  describe("meta-transactions", async () => {
    beforeEach("set web3 provider", async () => {
      web3.setProvider(ganache.provider({ accounts: metaTxsAccounts }));
    });

    it("should create a horse", async () => {
      let functionSignature = web3.eth.abi.encodeFunctionCall(
        await funcFromABI(breeding.abi, "mix"),
        [2, 1, web3.utils.toHex("Azul"), amount]
      );

      assert.isFalse(await core.tokenExists(3));

      let typedData = await getTypedData({
        name: "ZED Breeding",
        version: "1",
        chainId: chainId,
        verifyingContract: breeding.address,
        nonce: await breeding.getNonce(owner),
        from: owner,
        functionSignature: functionSignature,
      });

      let signedData = await signTxData(owner, typedData);

      let { r, s, v } = await getRsvFromSig(signedData);

      await breeding.executeMetaTransaction(owner, functionSignature, r, s, v);

      assert.isTrue(await core.tokenExists(3));
      assert.equal(await core.nextTokenId(), 4);
    });
  });

  describe("funds transfer", async () => {
    describe("different owners", async () => {
      // Horse 2 is in stud for 1 day and belongs to acc[2]

      it("sends correct amounts for 1 day in stud", async () => {
        let mix = await breeding.mix(2, 1, web3.utils.toHex("Color"), amount);
        let mixLogs = mix.receipt.logs[0].args;

        assert.equal(
          mixLogs._studOwner.toString(),
          web3.utils.toWei("0.08", "ether")
        );
        assert.equal(
          mixLogs._racesPool.toString(),
          web3.utils.toWei("0.09", "ether")
        );
        assert.equal(
          mixLogs._zed.toString(),
          web3.utils.toWei("0.03", "ether")
        );
      });

      it("sends correct amounts for 3 day in stud", async () => {
        await studService.removeFromStud(2);
        await studService.putInStud(2, amount, 259200);

        let mix = await breeding.mix(2, 1, web3.utils.toHex("Color"), amount);
        let mixLogs = mix.receipt.logs[0].args;

        assert.equal(
          mixLogs._studOwner.toString(),
          web3.utils.toWei("0.096", "ether")
        );
        assert.equal(
          mixLogs._racesPool.toString(),
          web3.utils.toWei("0.074", "ether")
        );
        assert.equal(
          mixLogs._zed.toString(),
          web3.utils.toWei("0.03", "ether")
        );
      });

      it("sends correct amounts for 7 day in stud", async () => {
        await studService.removeFromStud(2);
        await studService.putInStud(2, amount, 604800);

        let mix = await breeding.mix(2, 1, web3.utils.toHex("Color"), amount);
        let mixLogs = mix.receipt.logs[0].args;

        assert.equal(
          mixLogs._studOwner.toString(),
          web3.utils.toWei("0.112", "ether")
        );
        assert.equal(
          mixLogs._racesPool.toString(),
          web3.utils.toWei("0.058", "ether")
        );
        assert.equal(
          mixLogs._zed.toString(),
          web3.utils.toWei("0.03", "ether")
        );
      });
    });

    describe("same owners", async () => {
      beforeEach("transfer token", async () => {
        await core.transferFrom(acc[2], owner, 2, { from: acc[2] });
      });

      // Horse 2 is in stud for 1 day and already belongs to 'owner'.

      it("sends correct amounts for 1 day in stud", async () => {
        let mix = await breeding.mix(2, 1, web3.utils.toHex("Color"), amount);
        let mixLogs = mix.receipt.logs[0].args;

        assert.equal(mixLogs._studOwner.toString(), "0");
        assert.equal(mixLogs._racesPool.toString(), web3.utils.toWei("0.14"));
        assert.equal(mixLogs._zed.toString(), web3.utils.toWei("0.06"));
      });

      it("sends correct amounts for 3 day in stud", async () => {
        await studService.removeFromStud(2);
        await studService.putInStud(2, amount, 259200);

        let mix = await breeding.mix(2, 1, web3.utils.toHex("Color"), amount);
        let mixLogs = mix.receipt.logs[0].args;

        assert.equal(mixLogs._studOwner.toString(), "0");
        assert.equal(mixLogs._racesPool.toString(), web3.utils.toWei("0.14"));
        assert.equal(mixLogs._zed.toString(), web3.utils.toWei("0.06"));
      });

      it("sends correct amounts for 7 day in stud", async () => {
        await studService.removeFromStud(2);
        await studService.putInStud(2, amount, 604800);

        let mix = await breeding.mix(2, 1, web3.utils.toHex("Color"), amount);
        let mixLogs = mix.receipt.logs[0].args;

        assert.equal(mixLogs._studOwner.toString(), "0");
        assert.equal(mixLogs._racesPool.toString(), web3.utils.toWei("0.14"));
        assert.equal(mixLogs._zed.toString(), web3.utils.toWei("0.06"));
      });
    });
  });

  let createOffspring = async (male, female, color, from, wantedGender) => {
    let offspringId;

    while (true) {
      offspringId = await core.nextTokenId();
      await breeding.mix(male, female, web3.utils.toHex(color), amount, {
        from: from,
      });

      let sex = await breeding.getHorseSex(offspringId);

      if (web3.utils.toUtf8(sex) === wantedGender) {
        break;
      }
    }

    return offspringId;
  };
});
