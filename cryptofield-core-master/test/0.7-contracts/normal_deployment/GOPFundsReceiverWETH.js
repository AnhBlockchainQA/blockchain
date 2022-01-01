const GOPFundsReceiverWETH = artifacts.require("GOPFundsReceiverWETH.sol");
const Core = artifacts.require("Core");
const HorseData = artifacts.require("HorseData");
const ERC20Test = artifacts.require("ERC20Test");
const ganache = require("ganache-core");

import {
  funcFromABI,
  signTxData,
  getTypedData,
  getRsvFromSig,
  metaTxsAccounts,
} from "../../utils";

contract("GOPFundsReceiverWETH", (accounts) => {
  const maxWETH = web3.utils.toWei("1000", "ether");

  const owner = accounts[0];
  const fundsReceiver = accounts[1];
  const nextFundsReceiver = accounts[2];
  const blockchainBrain = accounts[3];
  const bob = accounts[4];
  const sasha = accounts[5];
  const emily = accounts[6];

  // Contracts instances
  let wethFundsReceiver, erc20, horseData, core, chainId;
  let amount = web3.utils.toWei("0.2", "ether");

  beforeEach("contracts instantiation", async () => {
    erc20 = await ERC20Test.new(web3.utils.toWei("100", "ether"));
    horseData = await HorseData.new();
    core = await Core.new(horseData.address);

    wethFundsReceiver = await GOPFundsReceiverWETH.new(
      fundsReceiver,
      core.address,
      erc20.address
    );

    chainId = await web3.eth.net.getId();

    wethFundsReceiver.grantRole(
      web3.utils.toHex("gfr_owners"),
      blockchainBrain
    );
  });

  beforeEach("setup erc20 tokens", async () => {
    await erc20.transfer(bob, amount);
    await erc20.transfer(emily, amount);
    await erc20.approve(wethFundsReceiver.address, maxWETH, {
      from: bob,
    });
    await erc20.approve(wethFundsReceiver.address, maxWETH, {
      from: sasha,
    });
    await erc20.approve(wethFundsReceiver.address, maxWETH, {
      from: emily,
    });
    await erc20.approve(wethFundsReceiver.address, maxWETH);
  });

  beforeEach("setup initial state of instances", async () => {
    await wethFundsReceiver.setDomainSeparator(
      "ZED WETH Funds Receiver",
      "1",
      chainId
    );

    await core.grantRole(web3.utils.toHex("core_contracts"), owner);

    // 0
    await core.mintCustomHorse(
      owner,
      4,
      web3.utils.toHex("Male"),
      web3.utils.toHex("FirstName"),
      web3.utils.toHex("Black")
    );

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
      bob,
      4,
      web3.utils.toHex("Male"),
      web3.utils.toHex("Trung"),
      web3.utils.toHex("blue")
    );
  });

  describe("Initial data validation", async () => {
    it("should make owner admin of contract after deployment", async () => {
      const isOwnerAdmin = await wethFundsReceiver.hasRole(
        web3.utils.asciiToHex("gfr_owners_admin"),
        owner
      );
      assert(isOwnerAdmin);
    });

    it("should not make the owner the funds receiver", async () => {
      assert.isFalse(
        await wethFundsReceiver.isFundsReceiver({
          from: owner,
        })
      );
    });

    it("should assign the funds receiver to the address in the constructor", async () => {
      assert(
        await wethFundsReceiver.isFundsReceiver({
          from: fundsReceiver,
        })
      );
    });
  });

  describe("getters and setters", async () => {
    it("should change funds receiver wallet", async () => {
      assert(
        await wethFundsReceiver.isFundsReceiver({
          from: fundsReceiver,
        })
      );
      await wethFundsReceiver.changeFundsReceiver(nextFundsReceiver, {
        from: blockchainBrain,
      });
      assert(
        await wethFundsReceiver.isFundsReceiver({
          from: nextFundsReceiver,
        })
      );
    });
  });

  describe("pausable", async () => {
    it("can only be paused by accounts with correct role", async () => {
      await wethFundsReceiver.pause({ from: blockchainBrain });
      await wethFundsReceiver.unpause({ from: blockchainBrain });

      try {
        await wethFundsReceiver.pause({ from: bob });
        assert.fail("Expected revert not received");
      } catch (error) {
        assert.equal(error.reason, "GOP: Unauthorized");
      }
    });

    it("should revert if contract is paused", async () => {
      await wethFundsReceiver.pause({ from: blockchainBrain });

      try {
        await wethFundsReceiver.receiveGOPFunds(
          web3.utils.asciiToHex("horse_code"),
          amount,
          web3.utils.asciiToHex("Bojack Horseman"),
          {
            from: bob,
          }
        );
        assert.fail("Expected revert not received");
      } catch (error) {
        assert.equal(error.reason, "Pausable: paused");
      }
    });

    it("should be able to receive funds after unpaused", async () => {
      await wethFundsReceiver.pause({ from: blockchainBrain });
      await wethFundsReceiver.unpause({ from: blockchainBrain });
      await wethFundsReceiver.receiveGOPFunds(
        web3.utils.asciiToHex("horse_code"),
        amount,
        web3.utils.asciiToHex("Bojack Horseman"),
        {
          from: bob,
        }
      );
      assert.equal(await erc20.balanceOf(fundsReceiver), amount);
      assert.equal(await erc20.balanceOf(bob), 0);
    });
  });

  describe("funds receiving", async () => {
    it("should fail for insufficient funds", async () => {
      try {
        assert.equal(await erc20.balanceOf(sasha), 0);
        await wethFundsReceiver.receiveGOPFunds(
          web3.utils.asciiToHex("horse_code"),
          amount,
          web3.utils.asciiToHex("Bojack Horseman"),
          {
            from: sasha,
          }
        );
        assert.fail("Expected revert not received");
      } catch (error) {
        assert.equal(error.reason, "ERC20: transfer amount exceeds balance");
      }
      assert.equal(await erc20.balanceOf(fundsReceiver), 0);
    });

    it("should fail for unnamed _horseName", async () => {
      try {
        await wethFundsReceiver.receiveGOPFunds(
          web3.utils.asciiToHex(""),
          amount,
          web3.utils.asciiToHex("Bojack Horseman"),
          {
            from: bob,
          }
        );
        assert.fail("Expected revert not received");
      } catch (error) {
        assert.equal(error.reason, "GOP: Code cannot be an empty string");
      }
      assert.equal(await erc20.balanceOf(fundsReceiver), 0);
    });

    it("should fail for 0 _horsePrice", async () => {
      try {
        await wethFundsReceiver.receiveGOPFunds(
          web3.utils.asciiToHex("horse_code"),
          0,
          web3.utils.asciiToHex("Bojack Horseman"),
          {
            from: bob,
          }
        );
        assert.fail("Expected revert not received");
      } catch (error) {
        assert.equal(error.reason, "GOP: Price cannot be 0");
      }
      assert.equal(await erc20.balanceOf(fundsReceiver), 0);
    });

    it("should transfer funds to fundsReceiver", async () => {
      await wethFundsReceiver.receiveGOPFunds(
        web3.utils.asciiToHex("horse_code"),
        amount,
        web3.utils.asciiToHex("Bojack Horseman"),
        {
          from: bob,
        }
      );
      assert.equal(await erc20.balanceOf(fundsReceiver), amount);
      assert.equal(await erc20.balanceOf(bob), 0);
    });

    it("should fail for already used _horseName", async () => {
      try {
        await wethFundsReceiver.receiveGOPFunds(
          web3.utils.asciiToHex("horse_code"),
          amount,
          web3.utils.asciiToHex("Trung"),
          {
            from: bob,
          }
        );
        assert.fail("Expected revert not received");
      } catch (error) {
        assert.equal(error.reason, "Core: name already taken");
      }
    });
  });

  describe("isCodeUsed mapping", async () => {
    it("should fail after receiving funds more than once for the same horse", async () => {
      await wethFundsReceiver.receiveGOPFunds(
        web3.utils.asciiToHex("horse_code"),
        amount,
        web3.utils.asciiToHex("Bojack Horseman"),
        {
          from: bob,
        }
      );

      try {
        await wethFundsReceiver.receiveGOPFunds(
          web3.utils.asciiToHex("horse_code"),
          amount,
          web3.utils.asciiToHex("Bojack Horseman"),
          {
            from: emily,
          }
        );
        assert.fail("Expected revert not received");
      } catch (error) {
        assert.equal(error.reason, "GOP: Code has already been used");
      }
      assert.equal(await erc20.balanceOf(fundsReceiver), amount);
      assert.equal(await erc20.balanceOf(bob), 0);
      assert.equal(await erc20.balanceOf(emily), amount);
    });

    it("should not be able to receive funds for code mark as used", async () => {
      try {
        await wethFundsReceiver.markCodeAsUsed(
          web3.utils.asciiToHex("horse_code"),
          { from: blockchainBrain }
        );
        await wethFundsReceiver.receiveGOPFunds(
          web3.utils.asciiToHex("horse_code"),
          amount,
          web3.utils.asciiToHex("Bojack Horseman"),
          {
            from: bob,
          }
        );
        assert.fail("Expected revert not received");
      } catch (error) {
        assert.equal(error.reason, "GOP: Code has already been used");
      }
      assert.equal(await erc20.balanceOf(fundsReceiver), 0);
    });

    it("should be able to receive funds for code mark as unused", async () => {
      await wethFundsReceiver.markCodeAsUsed(
        web3.utils.asciiToHex("horse_code"),
        { from: blockchainBrain }
      );
      await wethFundsReceiver.markCodeAsUnused(
        web3.utils.asciiToHex("horse_code"),
        { from: blockchainBrain }
      );
      await wethFundsReceiver.receiveGOPFunds(
        web3.utils.asciiToHex("horse_code"),
        amount,
        web3.utils.asciiToHex("Bojack Horseman"),
        {
          from: bob,
        }
      );
      assert.equal(await erc20.balanceOf(fundsReceiver), amount);
      assert.equal(await erc20.balanceOf(bob), 0);
    });
  });

  describe("meta-transactions", async () => {
    beforeEach("set web3 provider", async () => {
      web3.setProvider(ganache.provider({ accounts: metaTxsAccounts }));
    });

    it("sends funds to fundReceiver with meta-txs", async () => {
      const initialOwnerBalance = await erc20.balanceOf(owner);
      let functionSignature = web3.eth.abi.encodeFunctionCall(
        await funcFromABI(wethFundsReceiver.abi, "receiveGOPFunds"),
        [
          web3.utils.asciiToHex("horse_code"),
          amount,
          web3.utils.asciiToHex("Bojack Horseman"),
        ]
      );

      let typedData = await getTypedData({
        name: "ZED WETH Funds Receiver",
        version: "1",
        chainId: chainId,
        verifyingContract: wethFundsReceiver.address,
        nonce: await wethFundsReceiver.getNonce(owner),
        from: owner,
        functionSignature: functionSignature,
      });

      let signedData = await signTxData(owner, typedData);

      let { r, s, v } = await getRsvFromSig(signedData);

      await wethFundsReceiver.executeMetaTransaction(
        owner,
        functionSignature,
        r,
        s,
        v
      );

      assert.equal(await erc20.balanceOf(fundsReceiver), amount);
      assert.equal(await erc20.balanceOf(owner), initialOwnerBalance - amount);
    });
  });
});
