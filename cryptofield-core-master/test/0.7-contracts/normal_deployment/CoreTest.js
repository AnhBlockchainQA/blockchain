const Core = artifacts.require("Core");
const HorseData = artifacts.require("HorseData");
const ganache = require("ganache-core");

import {
  funcFromABI,
  signTxData,
  getTypedData,
  getRsvFromSig,
  metaTxsAccounts,
} from "../../utils";

contract("Core", (acc) => {
  let core, horseData, chainId;
  let owner = acc[0];

  beforeEach("setup instances", async () => {
    horseData = await HorseData.new();
    core = await Core.new(horseData.address);
    chainId = await web3.eth.net.getId();

    await core.setDomainSeparator("ZED Horse", "1", chainId);

    await core.grantRole(web3.utils.toHex("core_owners"), owner);
    await core.grantRole(web3.utils.toHex("core_contracts"), owner);

    // We cannot interact with ID 0
    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Male"),
      web3.utils.toHex("FirstName"),
      web3.utils.toHex("Black")
    );
  });

  describe("mintCustomHorse", async () => {
    it("should mint a horse with correct attributes", async () => {
      let tx = await core.mintCustomHorse(
        owner,
        4,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Miguel"),
        web3.utils.toHex("Blue")
      );

      let data = await core.getHorseData(1);

      assert.equal(web3.utils.hexToUtf8(data["0"]), "M");
      assert.isAbove(data["1"].toNumber(), 4);
      assert.isBelow(data["1"].toNumber(), 75);
      assert.equal(data["3"], 4);
      assert.equal(web3.utils.hexToUtf8(data["4"]), "S");
      assert.equal(web3.utils.hexToUtf8(data["5"]), "Colt");
      assert.equal(web3.utils.hexToUtf8(data["6"]), "Miguel");
      assert.equal(web3.utils.hexToUtf8(data["7"]), "Blue");

      let logs = tx.receipt.logs.map((log) => log.event);

      assert.equal(logs.indexOf("Transfer"), 0);
      assert.equal(logs.indexOf("LogGOPCreated"), 1);

      assert.equal(
        await core.tokenURI(1),
        "https://api.zed.run/api/v1/horses/metadata/1"
      );
    });

    it("should select the correct range of base value depending on the gen", async () => {
      await core.mintCustomHorse(
        owner,
        1,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Name"),
        web3.utils.toHex("Black")
      );

      let baseValue = await core.getBaseValue(1);

      assert.isAtLeast(web3.utils.toBN(baseValue).toNumber(), 95);
      assert.isAtMost(web3.utils.toBN(baseValue).toNumber(), 99);

      await core.mintCustomHorse(
        owner,
        2,
        web3.utils.toHex("Male"),
        web3.utils.toHex("SecondName"),
        web3.utils.toHex("Black")
      );

      baseValue = await core.getBaseValue(2);

      assert.isAtMost(baseValue.toNumber(), 89);
      assert.isAtLeast(baseValue.toNumber(), 80);
    });

    it("should revert if genotype is out of bounds", async () => {
      try {
        await core.mintCustomHorse(
          owner,
          12,
          web3.utils.toHex("Male"),
          web3.utils.toHex("MyNameIs"),
          web3.utils.toHex("Color")
        );

        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Core: gen out of bounds");
      }
    });

    it("should revert if name is taken", async () => {
      try {
        await core.mintCustomHorse(
          owner,
          1,
          web3.utils.toHex("Male"),
          web3.utils.toHex("FirstName"),
          web3.utils.toHex("Color")
        );

        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Core: name already taken");
      }
    });
  });

  describe("mintOffspring", async () => {
    // The 'owner' address has the 'core_contracts' role
    it("should mint an offspring with default name", async () => {
      await core.mintCustomHorse(
        owner,
        2,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Male Name"),
        web3.utils.toHex("Color")
      ); // ID 1

      await core.mintCustomHorse(
        owner,
        2,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Female Name"),
        web3.utils.toHex("Color")
      ); // ID 2

      await core.mintOffspring(owner, 1, 2, web3.utils.toHex("The Color"));

      let horseData = await core.getHorseData(3);

      assert.equal(web3.utils.hexToUtf8(horseData["6"]), "Unnamed Foal");
    });

    it("should mint an offspring with parent's bloodline", async () => {
      await core.mintCustomHorse(
        owner,
        2,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Male Name"),
        web3.utils.toHex("Color")
      ); // ID 1

      await core.mintCustomHorse(
        owner,
        1,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Female Name"),
        web3.utils.toHex("Color")
      ); // ID 2

      await core.mintOffspring(owner, 1, 2, web3.utils.toHex("Some Color"));

      let horseData = await core.getHorseData(3);

      assert.equal(web3.utils.hexToUtf8(horseData["4"]), "N");
    });

    it("should update horse type of parents", async () => {
      await core.mintCustomHorse(
        owner,
        2,
        web3.utils.toHex("Male"),
        web3.utils.toHex("Male Name"),
        web3.utils.toHex("Color")
      ); // ID 1

      await core.mintCustomHorse(
        owner,
        1,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Female Name"),
        web3.utils.toHex("Color")
      ); // ID 2

      await core.mintOffspring(owner, 1, 2, web3.utils.toHex("Color"));

      let parentData = await core.getHorseData(1);
      let motherData = await core.getHorseData(2);

      assert.equal(web3.utils.hexToUtf8(parentData["5"]), "Stallion");
      assert.equal(web3.utils.hexToUtf8(motherData["5"]), "Mare");
    });
  });

  describe("set/get", async () => {
    it("should return and set the URI base", async () => {
      let uriBase = await core.baseURI();
      assert.equal(uriBase, "https://api.zed.run/api/v1/horses/metadata/");

      await core.setBaseURI("MyURIBase", { from: owner });

      uriBase = await core.baseURI();
      assert.equal(uriBase, "MyURIBase");
    });
  });

  describe("view", async () => {
    it("should return whether or not a token exists", async () => {
      assert.isTrue(await core.tokenExists(0));
      assert.isFalse(await core.tokenExists(1));

      await core.mintCustomHorse(
        owner,
        1,
        web3.utils.toHex("Female"),
        web3.utils.toHex("Name"),
        web3.utils.toHex("Black")
      );

      assert.isTrue(await core.tokenExists(1));
    });
  });

  describe("protected functions", async () => {
    it("should allow admin to transfer tokens", async () => {
      assert.equal(await core.ownerOf(0), owner);

      let tx = await core.adminTransferToken(0, acc[1]);

      assert.equal(await core.ownerOf(0), acc[1]);
      assert.equal(tx.receipt.logs[1].event, "Transfer");
    });

    it("should fail if non admin calls tries to transfer", async () => {
      try {
        await core.adminTransferToken(0, acc[1], { from: acc[3] });

        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Core: unauthorized");
      }
    });

    describe("pausing contract", async () => {
      it("cannot create horses if contract is paused", async () => {
        await core.pause();

        try {
          await core.mintCustomHorse(
            owner,
            1,
            web3.utils.toHex("Female"),
            web3.utils.toHex("Migz"),
            web3.utils.toHex("Negro")
          );

          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "Pausable: paused");
        }
      });

      it("cannot transfer tokens when contract is paused", async () => {
        await core.pause();

        try {
          await core.transferFrom(owner, acc[1], 0, { from: owner });

          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(
            err.reason,
            "ERC721Pausable: token transfer while paused"
          );
        }

        try {
          await core.safeTransferFrom(owner, acc[1], 0, { from: owner });

          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(
            err.reason,
            "ERC721Pausable: token transfer while paused"
          );
        }
      });
    });

    describe("roles", async () => {
      it("should allow admins to grant admin roles", async () => {
        await core.grantRoleAdmin(
          web3.utils.toHex("core_owners_admin"),
          acc[1]
        );

        assert.isTrue(
          await core.hasRole(web3.utils.toHex("core_owners_admin"), acc[1])
        );
      });

      it("should revert if non-admin wants to grant admin role", async () => {
        try {
          await core.grantRoleAdmin(
            web3.utils.toHex("core_owners_admin"),
            acc[1],
            { from: acc[2] }
          );

          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "Core: unauthorized");
        }
      });

      it("should allow owners admins to grant another type of admin role", async () => {
        await core.grantRoleAdmin(
          web3.utils.toHex("core_contracts_admin"),
          acc[1]
        );

        assert.isTrue(
          await core.hasRole(web3.utils.toHex("core_contracts_admin"), acc[1])
        );
      });

      it("should revert caller does not have core_owners_admin role when grantin role without verification", async () => {
        await core.grantRoleAdmin(
          web3.utils.toHex("core_contracts_admin"),
          acc[1]
        );

        try {
          await core.grantRoleAdmin(
            web3.utils.toHex("core_owners_admin"),
            acc[4],
            { from: acc[1] }
          );

          assert.fail("Expected revert not received");
        } catch (err) {
          assert.equal(err.reason, "Core: unauthorized");
        }
      });
    });
  });

  describe("mint token with horse data", async () => {
    it("should mint a token with the specified horse data", async () => {
      let tokenId = 5;
      let sex = "M";
      let baseValue = 4;
      let timestamp = Date.now();
      let genotype = 4;
      let bloodline = "S";
      let hType = "Colt";
      let name = "Trung";
      let color = "White";

      let tx = await core.mintTokenWithHorseData(
        owner,
        tokenId,
        web3.utils.toHex(sex),
        baseValue,
        timestamp,
        genotype,
        web3.utils.toHex(bloodline),
        web3.utils.toHex(hType),
        web3.utils.toHex(name),
        web3.utils.toHex(color)
      );

      let data = await core.getHorseData(tokenId);

      assert.equal(web3.utils.hexToUtf8(data["0"]), sex);
      assert.equal(data["1"].toNumber(), baseValue);
      assert.equal(data["2"].toNumber(), timestamp);
      assert.equal(data["3"].toNumber(), genotype);
      assert.equal(web3.utils.hexToUtf8(data["4"]), bloodline);
      assert.equal(web3.utils.hexToUtf8(data["5"]), hType);
      assert.equal(web3.utils.hexToUtf8(data["6"]), name);
      assert.equal(web3.utils.hexToUtf8(data["7"]), color);

      let logs = tx.receipt.logs.map((log) => log.event);

      assert.equal(logs.indexOf("Transfer"), 0);
      assert.equal(logs.indexOf("LogMintTokenWithHorseData"), 1);

      assert.equal(await core.ownerOf(tokenId), owner);
    });
  });

  describe("batch mint token with horse data", async () => {
    it("should mint multiple tokens with the specified horse data list", async () => {
      let tokenId = 5;
      let sex = "M";
      let baseValue = 4;
      let timestamp = Date.now();
      let genotype = 4;
      let bloodline = "S";
      let hType = "Colt";
      let hType2 = "Filly";
      let name = "Trung";
      let name2 = "Mila";
      let color = "White";
      let color2 = "Blue";

      let tx = await core.mintTokenWithHorseDataBatch(
        [owner, acc[1]],
        [tokenId, tokenId + 1],
        [web3.utils.toHex(sex), web3.utils.toHex(sex)],
        [baseValue, baseValue + 1],
        [timestamp, timestamp + 1000],
        [genotype, genotype + 1],
        [web3.utils.toHex(bloodline), web3.utils.toHex(bloodline)],
        [web3.utils.toHex(hType), web3.utils.toHex(hType2)],
        [web3.utils.toHex(name), web3.utils.toHex(name2)],
        [web3.utils.toHex(color), web3.utils.toHex(color2)]
      );

      let data = await core.getHorseData(tokenId);

      assert.equal(web3.utils.hexToUtf8(data["0"]), sex);
      assert.equal(data["1"].toNumber(), baseValue);
      assert.equal(data["2"].toNumber(), timestamp);
      assert.equal(data["3"].toNumber(), genotype);
      assert.equal(web3.utils.hexToUtf8(data["4"]), bloodline);
      assert.equal(web3.utils.hexToUtf8(data["5"]), hType);
      assert.equal(web3.utils.hexToUtf8(data["6"]), name);
      assert.equal(web3.utils.hexToUtf8(data["7"]), color);

      data = await core.getHorseData(tokenId + 1);

      assert.equal(web3.utils.hexToUtf8(data["0"]), sex);
      assert.equal(data["1"].toNumber(), baseValue + 1);
      assert.equal(data["2"].toNumber(), timestamp + 1000);
      assert.equal(data["3"].toNumber(), genotype + 1);
      assert.equal(web3.utils.hexToUtf8(data["4"]), bloodline);
      assert.equal(web3.utils.hexToUtf8(data["5"]), hType2);
      assert.equal(web3.utils.hexToUtf8(data["6"]), name2);
      assert.equal(web3.utils.hexToUtf8(data["7"]), color2);

      let logs = tx.receipt.logs.map((log) => log.event);

      assert.equal(logs.indexOf("Transfer"), 0);
      assert.equal(logs.indexOf("LogMintTokenWithHorseDataBatch"), 2);

      assert.equal(await core.ownerOf(tokenId + 1), acc[1]);

      // Change horse name
      const newName = "Trung New";
      const newName2 = "Trung New 2";
      tx = await core.setHorseNameBatch(
        [tokenId, tokenId + 1],
        [web3.utils.toHex(newName), web3.utils.toHex(newName2)]
      );
      data = await core.getHorseData(tokenId);
      assert.equal(web3.utils.hexToUtf8(data["6"]), newName);
      data = await core.getHorseData(tokenId + 1);
      assert.equal(web3.utils.hexToUtf8(data["6"]), newName2);

      logs = tx.receipt.logs.map((log) => log.event);
      assert.equal(logs.indexOf("LogSetHorseNameBatch"), 0);

      // Test name uniqueness
      try {
        await core.setHorseNameBatch(
          [tokenId, tokenId + 1],
          [web3.utils.toHex(newName), web3.utils.toHex(newName2)]
        );
        assert.fail("Expected revert was not received");
      } catch (err) {
        assert.equal(err.reason, "Core: name already taken");
      }
    });

    it("should not mint anything with empty data list", async () => {
      let tokenId = 5;
      let tx = await core.mintTokenWithHorseDataBatch(
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        []
      );

      let logs = tx.receipt.logs.map((log) => log.event);

      assert.equal(logs.indexOf("LogMintTokenWithHorseDataBatch"), 0);

      assert.isFalse(await core.tokenExists(tokenId));
    });
  });

  describe("burning", async () => {
    it("burns a token and does not affect the next token ID", async () => {
      await core.mintCustomHorse(
        owner,
        1,
        web3.utils.toHex("Female"),
        web3.utils.toHex("VHS"),
        web3.utils.toHex("Negro")
      );

      let horseData = await core.getHorseData(1);

      assert.equal(web3.utils.hexToUtf8(horseData["7"]), "Negro");

      assert.isTrue(await core.tokenExists(1));
      assert.equal((await core.nextTokenId()).toNumber(), 2);

      await core.burn(1);

      horseData = await core.getHorseData(1);

      assert.equal((await core.nextTokenId()).toNumber(), 2);
      assert.notEqual(web3.utils.hexToUtf8(horseData["7"]), "Negro");

      // The total supply is affected, not the next token ID
      assert.equal((await core.totalSupply()).toNumber(), 1);
    });

    it("reverts if sender is not owner of token", async () => {
      try {
        await core.burn(0, { from: acc[1] });
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Core: not owner of token");
      }
    });

    it("reverts if token does not exist", async () => {
      try {
        await core.burn(1);
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Core: token does not exist");
      }
    });
  });

  describe("setting name", async () => {
    it("sets the name of the horse", async () => {
      await core.mintCustomHorse(
        owner,
        1,
        web3.utils.toHex("Male"),
        web3.utils.toHex("VHS"),
        web3.utils.toHex("Black")
      );

      await core.setHorseName(1, web3.utils.toHex("New Name"));

      let horseData = await core.getHorseData(1);

      assert.equal(web3.utils.hexToUtf8(horseData["6"]), "New Name");
    });

    it("reverts if name is already taken", async () => {
      // Token 0 from setup's name is FirstName
      try {
        await core.setHorseName(0, web3.utils.toHex("FirstName"));
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "Core: name already taken");
      }
    });
  });

  describe("meta-transactions", async () => {
    beforeEach("set web3 provider", async () => {
      web3.setProvider(ganache.provider({ accounts: metaTxsAccounts }));
    });

    it("should create a horse through a meta-tx", async () => {
      // This tests the `core_contracts` role
      let functionSignature = web3.eth.abi.encodeFunctionCall(
        await funcFromABI(core.abi, "mintCustomHorse"),
        [
          owner,
          3,
          web3.utils.toHex("Male"),
          web3.utils.toHex("SecondName"),
          web3.utils.toHex("Negro"),
        ]
      );

      let typedData = await getTypedData({
        name: "ZED Horse",
        version: "1",
        chainId: chainId,
        verifyingContract: core.address,
        nonce: await core.getNonce(owner),
        from: owner,
        functionSignature: functionSignature,
      });

      let signedData = await signTxData(owner, typedData);
      let { r, s, v } = await getRsvFromSig(signedData);

      await core.executeMetaTransaction(owner, functionSignature, r, s, v);

      let data = await core.getHorseData(1);

      assert.equal(web3.utils.hexToUtf8(data["0"]), "M");
      assert.isAbove(data["1"].toNumber(), 4);
      assert.isBelow(data["1"].toNumber(), 80);
      assert.equal(data["3"], 3);
      assert.equal(web3.utils.hexToUtf8(data["4"]), "S");
      assert.equal(web3.utils.hexToUtf8(data["5"]), "Colt");
      assert.equal(web3.utils.hexToUtf8(data["6"]), "SecondName");
      assert.equal(web3.utils.hexToUtf8(data["7"]), "Negro");
    });

    it("should transfer a horse through a meta-tx", async () => {
      // Since ID 0 is created already we're going to use that one
      let functionSignature = web3.eth.abi.encodeFunctionCall(
        await funcFromABI(core.abi, "transferFrom"),
        [owner, acc[1], 0]
      );

      let typedData = await getTypedData({
        name: "ZED Horse",
        version: "1",
        chainId: chainId,
        verifyingContract: core.address,
        nonce: await core.getNonce(owner),
        from: owner,
        functionSignature: functionSignature,
      });

      let signedData = await signTxData(owner, typedData);
      let { r, s, v } = await getRsvFromSig(signedData);

      await core.executeMetaTransaction(owner, functionSignature, r, s, v);

      assert.equal(await core.ownerOf(0), acc[1]);
    });

    it("should revert if user has no rights for token transfer", async () => {
      let functionSignature = web3.eth.abi.encodeFunctionCall(
        await funcFromABI(core.abi, "transferFrom"),
        [owner, acc[1], 0]
      );

      let typedData = await getTypedData({
        name: "ZED Horse",
        version: "1",
        chainId: chainId,
        verifyingContract: core.address,
        nonce: await core.getNonce(acc[1]),
        from: acc[1],
        functionSignature: functionSignature,
      });

      let signedData = await signTxData(acc[1], typedData);
      let { r, s, v } = await getRsvFromSig(signedData);

      try {
        await core.executeMetaTransaction(acc[1], functionSignature, r, s, v);
        assert.fail("Expected revert not received");
      } catch (err) {
        assert.equal(err.reason, "EIP712: Function call not successful");
      }
    });

    it("should burn a token for an user", async () => {
      await core.mintCustomHorse(
        acc[4],
        1,
        web3.utils.toHex("Female"),
        web3.utils.toHex("FemHorse"),
        web3.utils.toHex("Pink")
      );

      assert.isTrue(await core.tokenExists(1));

      let functionSignature = web3.eth.abi.encodeFunctionCall(
        await funcFromABI(core.abi, "burn"),
        [1]
      );

      let typedData = await getTypedData({
        name: "ZED Horse",
        version: "1",
        chainId: chainId,
        verifyingContract: core.address,
        nonce: await core.getNonce(acc[4]),
        from: acc[4],
        functionSignature: functionSignature,
      });

      let signedData = await signTxData(acc[4], typedData);
      let { r, s, v } = await getRsvFromSig(signedData);

      await core.executeMetaTransaction(acc[4], functionSignature, r, s, v);

      assert.isFalse(await core.tokenExists(1));
      assert.equal(await core.nextTokenId(), 2);
    });
  });
});
