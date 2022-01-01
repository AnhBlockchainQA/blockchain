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

contract("StudServiceV5", (acc) => {
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
    highMating = web3.utils.toWei("1", "ether"),
    lowMating = web3.utils.toWei("0.004", "ether"),
    seconds = {
      day1: 86400,
      day3: 259200,
      day6: 518400,
    },
    secondOwner = acc[2],
    randomAddress = acc[3],
    poolAddress = acc[9],
    amount = web3.utils.toWei("0.1", "ether");

  const STUD_OWNERS_ROLE = web3.utils.toHex("stud_owners");

  beforeEach("deploy instances", async () => {
    chainId = await web3.eth.net.getId();

    horseData = await HorseData.new();
    core = await Core.new(horseData.address);

    breedTypes = await BreedTypes.new();

    studService = await StudService.new(
      core.address,
      horseData.address,
      breedTypes.address
    );
    await studService.grantRole(web3.utils.toHex("stud_owners"), owner);

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
    await studService.setDomainSeparator("ZED Stud", "1", chainId);
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
      acc[2]
    );

    await breedTypes.grantRole(
      web3.utils.toHex("breed_types_contracts"),
      breeding.address
    );

    // Core need to grant CORE_CONTRACTS_ROLE for Breeding to able to invoke method Core.mintOffspring
    await core.grantRole(web3.utils.toHex("core_contracts"), breeding.address);

    await erc20.transfer(acc[2], amount);
    await erc20.approve(breeding.address, maxWETH, {
      from: acc[2],
    });
    await erc20.approve(breeding.address, maxWETH);

    await createInitialHorses();
  });

  const createInitialHorses = async () => {
    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Female"),
      web3.utils.toHex("Truc1"),
      web3.utils.toHex("violet")
    );

    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Male"),
      web3.utils.toHex("Trung1"),
      web3.utils.toHex("blue")
    );

    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Female"),
      web3.utils.toHex("Truc2"),
      web3.utils.toHex("violet")
    );

    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Male"),
      web3.utils.toHex("Trung2"),
      web3.utils.toHex("blue")
    );

    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Male"),
      web3.utils.toHex("Trung3"),
      web3.utils.toHex("blue")
    );
  };

  describe("Initial methods", () => {
    it("should check the emptiness of init state before adding horses to stud", async () => {
      const horsesInStud = await studService.getHorsesInStud();
      assert.equal(horsesInStud.length, 0);
    });
  });

  describe("Ownership checks", () => {
    it("should check deployer to admin of stud service", async () => {
      const isAdmin = await studService.hasRole(STUD_OWNERS_ROLE, owner);
      assert.deepEqual(isAdmin, true);
    });

    it("should add another address as admin of stud service", async () => {
      await studService.grantRole(STUD_OWNERS_ROLE, secondOwner, {
        from: owner,
      });
      const isAdmin = await studService.hasRole(STUD_OWNERS_ROLE, secondOwner);
      assert.deepEqual(isAdmin, true);
    });

    it("should revert transaction to protected method from non-registered addresses", async () => {
      try {
        await studService.grantRole(STUD_OWNERS_ROLE, secondOwner, {
          from: randomAddress,
        });
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(
          err.reason,
          "AccessControl: sender must be an admin to grant"
        );
      }
    });

    it("should renounce ownership and can't call methods after that", async () => {
      await studService.revokeRole(STUD_OWNERS_ROLE, secondOwner);

      try {
        await studService.grantRole(STUD_OWNERS_ROLE, randomAddress, {
          from: secondOwner,
        });
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(
          err.reason,
          "AccessControl: sender must be an admin to grant"
        );
      }
    });
  });

  describe("Stud admin methods checks", () => {
    it("should add new timeframe and check the state", async () => {
      const newTimeframe = 256000;
      let isNewTimeframeActive = await studService.isTimeframeExist(
        newTimeframe
      );
      assert.deepEqual(isNewTimeframeActive, false);

      await studService.addTimeFrame(newTimeframe, {
        from: owner,
      });
      isNewTimeframeActive = await studService.isTimeframeExist(newTimeframe);
      assert.deepEqual(isNewTimeframeActive, true);
    });

    it("should remove timeframe and check the state", async () => {
      const targetTimeframe = 86400;
      await studService.removeTimeFrame(targetTimeframe, {
        from: owner,
      });

      const isTargetTimeframeActive = await studService.isTimeframeExist(
        targetTimeframe
      );
      assert.deepEqual(isTargetTimeframeActive, false);
    });

    it("should set new base fee and check the state", async () => {
      let currentBaseFee = await studService.getBaseFee();
      assert.deepEqual(
        currentBaseFee.toString(),
        web3.utils.toWei("0.075", "ether")
      );

      await studService.setBaseFee(web3.utils.toWei("0.5", "ether"), {
        from: owner,
      });
      currentBaseFee = await studService.getBaseFee();
      assert.deepEqual(
        currentBaseFee.toString(),
        web3.utils.toWei("0.5", "ether")
      );
    });

    it("should set new breed type and check the state", async () => {
      const breedType = web3.utils.fromAscii("mustang");
      let newBreedTypeWeight = await studService.getBreedTypeWeight(breedType);
      assert.deepEqual(newBreedTypeWeight.toString(), "0");

      await studService.setBreedTypeWeight(breedType, 200, {
        from: owner,
      });

      newBreedTypeWeight = await studService.getBreedTypeWeight(breedType);
      assert.deepEqual(newBreedTypeWeight.toString(), "200");
    });

    it("should set new blood line weight and check the state", async () => {
      const bloodLine = web3.utils.fromAscii("X");
      let newBloodLineWeight = await studService.getBloodlineWeight(bloodLine);
      assert.deepEqual(newBloodLineWeight.toString(), "0");

      await studService.setBloodlineWeight(bloodLine, 200, {
        from: owner,
      });

      newBloodLineWeight = await studService.getBloodlineWeight(bloodLine);
      assert.deepEqual(newBloodLineWeight.toString(), "200");
    });

    it("should allow admin to put and remove horse on stud without value", async () => {
      await studService.adminPutInStud(2, highMating, seconds.day1, {
        from: owner,
      });

      let inStud = await studService.isHorseInStud(2);
      let matingPrice = await studService.getMatingPrice(2);
      let duration = await studService.getStudTime(2);

      assert.equal(inStud, true);
      assert.deepEqual(matingPrice.toString(), highMating);
      assert.deepEqual(duration.toString(), seconds.day1.toString());

      await studService.removeFromStud(2, {
        from: owner,
      });

      inStud = await studService.isHorseInStud(2);
      matingPrice = await studService.getMatingPrice(2);
      duration = await studService.getStudTime(2);

      assert.equal(inStud, false);
      assert.deepEqual(matingPrice.toString(), "0");
      assert.deepEqual(duration.toString(), "0");
    });
  });

  describe("Stud game logic checks", () => {
    it("should add first horse in stud and check the state", async () => {
      await studService.putInStud(2, highMating, seconds.day1);

      const studInfo = await studService.getStudInfo(2);
      const inStud = studInfo[0];
      const matingPrice = studInfo[1].toString();
      const duration = studInfo[2].toString();

      assert.equal(inStud, true);
      assert.deepEqual(matingPrice, highMating);
      assert.deepEqual(duration, seconds.day1.toString());
    });

    it("should remove first horse from stud and check the state", async () => {
      await studService.putInStud(2, highMating, seconds.day1, {
        from: owner,
      });

      // Removes horse from Stud list and changes status but can't be placed into Stud while
      // the specified time has not passed yet.
      await studService.removeFromStud(2, {
        from: owner,
      });

      const studInfo = await studService.getStudInfo(2);
      const inStud = studInfo[0];

      assert.equal(inStud, false);

      const horsesInStud = await studService.getHorsesInStud();
      assert.equal(horsesInStud.length, 0);
    });

    it("should add 2 horses to stud and check the state", async () => {
      // Add horses to stud
      await studService.putInStud(2, highMating, seconds.day1, {
        from: owner,
      });
      await studService.putInStud(4, highMating, seconds.day3, {
        from: owner,
      });

      // Get state of id2 horse
      let studInfo = await studService.getStudInfo(2);
      let inStud = studInfo[0];
      let matingPrice = studInfo[1].toString();
      let duration = studInfo[2].toString();

      assert.equal(inStud, true);
      assert.deepEqual(matingPrice, highMating);
      assert.deepEqual(duration, seconds.day1.toString());

      // Get state of id4 horse
      studInfo = await studService.getStudInfo(4);
      inStud = studInfo[0];
      matingPrice = studInfo[1].toString();
      duration = studInfo[2].toString();

      assert.equal(inStud, true);
      assert.deepEqual(matingPrice, highMating);
      assert.deepEqual(duration, seconds.day3.toString());

      const horsesInStud = await studService.getHorsesInStud();
      assert.equal(horsesInStud.length, 2);
      assert.deepEqual(horsesInStud.toString(), "2,4");
    });

    it("should remove horse from stud and check the state", async () => {
      await studService.putInStud(4, highMating, seconds.day1, {
        from: owner,
      });

      await studService.putInStud(2, highMating, seconds.day1, {
        from: owner,
      });

      // Removes horse from Stud list and changes status. It can't be placed into Stud while
      // the specified time has not passed yet (should be tested on the next test)
      await studService.removeFromStud(4, {
        from: owner,
      });

      const studInfo = await studService.getStudInfo(4);
      const inStud = studInfo[0];

      assert.equal(inStud, false);

      const horsesInStud = await studService.getHorsesInStud();
      assert.equal(horsesInStud.length, 1);
      assert.deepEqual(horsesInStud.toString(), "2");
    });

    it("should use a default value if a different time is sent", async () => {
      await core.mintCustomHorse(
        randomAddress,
        4,
        web3.utils.toHex("Male"),
        web3.utils.toHex("FirstName111"),
        web3.utils.toHex("Black")
      );

      // We'll use a random value for the duration since only three values are allowed at the moment.
      await studService.putInStud(6, highMating, 123456, {
        from: randomAddress,
      });

      let studInfo = await studService.getStudInfo(6);
      let time = await web3.utils.toBN(studInfo[2]).toNumber();

      // In case we change the time for dev. 1 day on prod.
      const expected = time === 3600 ? 86400 : time;

      assert.equal(expected, seconds.day1); // Default to three days.
    });

    it("should remove last horse from the list of horses in stud", async () => {
      await studService.putInStud(2, highMating, seconds.day1, {
        from: owner,
      });
      await studService.putInStud(4, highMating, seconds.day1, {
        from: owner,
      });

      // Horse 2 is in Stud at the moment.
      let horses = await studService.getHorsesInStud();
      assert.deepEqual(horses.toString(), "2,4");
      assert.deepEqual(horses.length, 2);

      await studService.removeFromStud(4, {
        from: owner,
      });
      horses = await studService.getHorsesInStud();

      assert.deepEqual(horses.toString(), "2");
      assert.deepEqual(horses.length, 1);
    });
  });

  describe("reverts", async () => {
    describe("putInStud", async () => {
      it("should revert when a different user than owner tries to put a horse in stud", async () => {
        try {
          await studService.putInStud(4, highMating, seconds.day6, {
            from: randomAddress,
          });
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "StudService: unauthorized");
        }
      });

      it("should revert if we try to put a female horse into stud", async () => {
        try {
          await studService.putInStud(1, highMating, seconds.day6, {
            from: owner,
          });
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "StudService: horse is not male");
        }
      });

      it("should revert if minimum breed price is lower than required", async () => {
        try {
          await studService.putInStud(
            2,
            web3.utils.toWei("0.0001", "ether"),
            seconds.day1
          );
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(
            err.reason,
            "StudService: mating price lower than minimum breed price"
          );
        }
      });
    });

    describe("pausable", async () => {
      it("can only be paused by accounts with correct role", async () => {
        await studService.pause();
        await studService.unpause();

        try {
          await studService.pause({ from: acc[1] });
          assert.faile("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "StudService: unauthorized owner admin");
        }
      });

      it("should revert if paused", async () => {
        assert.isFalse(await studService.paused());
        await studService.pause();
        assert.isTrue(await studService.paused());

        const minBreedingPrice = await studService.getMinimumBreedPrice(2);
        try {
          await studService.putInStud(2, minBreedingPrice, seconds.day1);
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "Pausable: paused");
        }

        await studService.unpause();
        assert.isFalse(await studService.paused());

        await studService.putInStud(2, minBreedingPrice, seconds.day1);

        await studService.pause();
        assert.isTrue(await studService.paused());

        try {
          await studService.removeFromStud(2);
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "Pausable: paused");
        }
      });
    });

    describe("addTimeFrame", async () => {
      it("reverts if timeframe is not > 0", async () => {
        try {
          await studService.addTimeFrame(0);
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "StudService: invalid seconds frame");
        }
      });

      it("reverts if timeframe already exists", async () => {
        try {
          await studService.addTimeFrame(86400);
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "StudService: seconds frame already active");
        }
      });
    });

    describe("setBreedTypesAddress", async () => {
      it("reverts if breedtypes address is 0", async () => {
        try {
          await studService.setBreedTypesAddress(
            "0x0000000000000000000000000000000000000000"
          );
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(
            err.reason,
            "StudService: invalid breedtypes contract address"
          );
        }
      });
    });

    describe("setCoreAddress", async () => {
      it("reverts if core address is 0", async () => {
        try {
          await studService.setCoreAddress(
            "0x0000000000000000000000000000000000000000"
          );
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(
            err.reason,
            "StudService: invalid core contract address"
          );
        }
      });
    });

    describe("removeTimeFrame", async () => {
      it("reverts if timeframe is not found when removing", async () => {
        try {
          await studService.removeTimeFrame(123);
          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "StudService: seconds frame is not found");
        }
      });
    });
  });

  describe("meta-transactions", async () => {
    beforeEach("set web3 provider", async () => {
      web3.setProvider(ganache.provider({ accounts: metaTxsAccounts }));
    });

    it("should put a horse in stud", async () => {
      let functionSignature = web3.eth.abi.encodeFunctionCall(
        await funcFromABI(studService.abi, "putInStud"),
        [2, highMating, seconds.day3]
      );

      assert.isFalse(await studService.isHorseInStud(2));

      let typedData = await getTypedData({
        name: "ZED Stud",
        version: "1",
        chainId: chainId,
        verifyingContract: studService.address,
        nonce: await studService.getNonce(owner),
        from: owner,
        functionSignature: functionSignature,
      });

      let signedData = await signTxData(owner, typedData);
      let { r, s, v } = await getRsvFromSig(signedData);

      await studService.executeMetaTransaction(
        owner,
        functionSignature,
        r,
        s,
        v
      );

      assert.isTrue(await studService.isHorseInStud(2));
    });
  });
});
