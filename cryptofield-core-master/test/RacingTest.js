const RacingArena = artifacts.require("RacingArena.sol")
const RacingProxy = artifacts.require("RacingProxy.sol")

contract("RacingArena", (accounts) => {
  const deployer = accounts[0]
  const upgradeAdmin = accounts[1]

  const admin_1 = accounts[3]
  const admin_2 = accounts[4]
  const admin_3 = accounts[5]

  const fee_wallet = accounts[6]

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

  // Addresses used only for constructor
  const core_contract_address = accounts[9]
  const weth_address = accounts[9];
  const bb_address = accounts[9]

  // Contracts instances
  let logicInstance, proxyInstance, contractInstance;

  beforeEach(async() => {
    // 1. Deploy logic contract
    logicInstance = await RacingArena.new();

    // 2. Deploy proxy contract (with logic contract address and with admin address, who can upgrade the logic on the future)
    proxyInstance = await RacingProxy.new(logicInstance.address, upgradeAdmin)

    // 3. Create instance of logic contract at proxy address
    contractInstance = await RacingArena.at(proxyInstance.address)

    await contractInstance.initSetup(bb_address, weth_address);
  })

  describe("Initial data validation", async() => {
    it("should make deployer admin of contract after deployment", async() => {
      const isDeployerAdmin = await contractInstance.isAdmin(deployer)
      assert.deepEqual(isDeployerAdmin, true)
    })

    it("should not make the deployer the fee receiver", async() => {
      const isDeployerFeeReceiver = await contractInstance.isFeeWallet({
        from: deployer
      })
      assert.deepEqual(isDeployerFeeReceiver, false)
    })

    it("should mark fee receiver as a zero address", async() => {
      const feeReceiver = await contractInstance.feeWallet()
      assert.deepEqual(feeReceiver, ZERO_ADDRESS)
    })

    it("should upgrade admin address with selected one", async() => {
      const proxyUpgradeAdmin = await proxyInstance.proxyAdmin()
      assert.deepEqual(upgradeAdmin, proxyUpgradeAdmin)
    })

    it("should return initial proxy implementation address", async() => {
      const logicAddress = logicInstance.address
      const implementationAddress = await proxyInstance.proxyImplementation()
      assert.deepEqual(logicAddress, implementationAddress)
    })

    it("should return initial proxy version", async() => {
      const implementationVersion = await proxyInstance.proxyVersion()
      assert.deepEqual(implementationVersion, "1.0.0")
    })
  })

  describe("Change the state before upgrade", async() => {
    it("adds new admins", async() => {
      await contractInstance.addAdmin(admin_1, {
        from: deployer
      })
      await contractInstance.addAdmin(admin_2, {
        from: admin_1
      })
      await contractInstance.addAdmin(admin_3, {
        from: admin_2
      })
    })

    it("adds fee receiver wallet", async() => {
      await contractInstance.transferFeeWalletOwnership(fee_wallet, {
        from: deployer
      })
    })
  })

  describe("Create race", async() => {
    it("creates new race", async() => {
      await contractInstance.createRace(
        "0x01",
        "Mumbai Race",
        "12",
        web3.utils.toWei("10", "finney"),
        "2000", {
          from: deployer
        }
      )
    })

    it("should return correct number of horses for new race", async() => {
      await contractInstance.createRace(
        "0x01",
        "Mumbai Race",
        "12",
        web3.utils.toWei("10", "finney"),
        "2000", {
          from: deployer
        }
      )

      let horses = await contractInstance.getHorsesInRace("0x01");

      assert.deepEqual(horses.length, 0)
    })
  })

  describe("Check the state after changes", async() => {
    it("should return recently added wallets for admin roles", async() => {
      await contractInstance.addAdmin(admin_2, {
        from: deployer
      });

      const isAdmin2 = await contractInstance.isAdmin(admin_2);

      assert.deepEqual(isAdmin2, true)
    })

    it("should check added wallet for fee wallet", async() => {
      await contractInstance.transferFeeWalletOwnership(fee_wallet, {
        from: deployer
      });

      const isFeeWallet = await contractInstance.isFeeWallet({
        from: fee_wallet
      })
      assert.deepEqual(isFeeWallet, true)
    })

    it("should check recently added race", async() => {
      await contractInstance.createRace(
        "0x01",
        "Mumbai Race",
        "12",
        web3.utils.toWei("10", "finney"),
        "2000", {
          from: deployer
        }
      )

      const isIdSaved = await contractInstance.ID_Saved("0x01")
      assert.deepEqual(isIdSaved, true)

      const raceData = await contractInstance.Races("0x01")
      const length = raceData["Length"].toString()
      const fee = raceData["Entrance_Fee"].toString()
      const horsesAllowed = raceData["Horses_Allowed"].toString()
      const state = raceData["Race_State"].toString()

      assert.deepEqual(length, "2000")
      assert.deepEqual(fee, web3.utils.toWei("10", "finney"))
      assert.deepEqual(horsesAllowed, "12")
      assert.deepEqual(state, "1")
    })
  })

  describe("Upgrade implementation contract", async() => {
    it("deploy new implementation contract and upgrade it on proxy address", async() => {
      const newLogic = await RacingArena.new(core_contract_address, bb_address)
      await proxyInstance.upgradeProxyTo(newLogic.address, "1.1.0", {
        from: upgradeAdmin
      })
    })
  })

  describe("Check the state after upgrade", async() => {
    it("should check wallets for admin roles", async() => {
      await contractInstance.addAdmin(admin_1, {
        from: deployer
      });

      await contractInstance.isAdmin(admin_1)

      const newLogic = await RacingArena.new(core_contract_address, bb_address)
      await proxyInstance.upgradeProxyTo(newLogic.address, "1.1.0", {
        from: upgradeAdmin
      })

      const isAdmin1 = await contractInstance.isAdmin(admin_1)

      assert.deepEqual(isAdmin1, true)
    })

    it("should check selected fee wallet", async() => {
      await contractInstance.transferFeeWalletOwnership(fee_wallet, {
        from: deployer
      });

      const newLogic = await RacingArena.new(core_contract_address, bb_address)
      await proxyInstance.upgradeProxyTo(newLogic.address, "1.1.0", {
        from: upgradeAdmin
      })

      const isFeeWallet = await contractInstance.isFeeWallet({
        from: fee_wallet
      })
      assert.deepEqual(isFeeWallet, true)
    })

    it("should check implementation address change", async() => {
      const newLogic = await RacingArena.new(core_contract_address, bb_address)
      await proxyInstance.upgradeProxyTo(newLogic.address, "1.1.0", {
        from: upgradeAdmin
      })

      const previusImplementation = logicInstance.address
      const currentImplementation = await proxyInstance.proxyImplementation()
      assert.notEqual(previusImplementation, currentImplementation)
    })

    it("should check the implementation version change", async() => {
      const newLogic = await RacingArena.new(core_contract_address, bb_address)
      await proxyInstance.upgradeProxyTo(newLogic.address, "1.1.0", {
        from: upgradeAdmin
      })

      const currentImplementation = await proxyInstance.proxyVersion()
      assert.deepEqual(currentImplementation, "1.1.0")
    })

    it("should check the previously added race", async() => {
      await contractInstance.createRace(
        "0x01",
        "Mumbai Race",
        "12",
        web3.utils.toWei("10", "finney"),
        "2000", {
          from: deployer
        }
      )

      const newLogic = await RacingArena.new(core_contract_address, bb_address)
      await proxyInstance.upgradeProxyTo(newLogic.address, "1.1.0", {
        from: upgradeAdmin
      })

      const isIdSaved = await contractInstance.ID_Saved("0x01")
      assert.deepEqual(isIdSaved, true)

      const raceData = await contractInstance.Races("0x01")
      const length = raceData["Length"].toString()
      const fee = raceData["Entrance_Fee"].toString()
      const horsesAllowed = raceData["Horses_Allowed"].toString()
      const state = raceData["Race_State"].toString()

      assert.deepEqual(length, "2000")
      assert.deepEqual(fee, web3.utils.toWei("10", "finney"))
      assert.deepEqual(horsesAllowed, "12")
      assert.deepEqual(state, "1")
    })
  })

  describe("Check the ownership who can upgrade contract", async() => {
    it("should check proxy admin address change", async() => {
      await proxyInstance.changeProxyAdmin(admin_1, {
        from: upgradeAdmin
      })

      const currentAdmin = await proxyInstance.proxyAdmin()
      assert.deepEqual(currentAdmin, admin_1)
    })

    it("should fail to upgrade proxy to non-contract address", async() => {
      try {
        await proxyInstance.upgradeProxyTo(deployer, "1.2.0", {
          from: upgradeAdmin
        })
        assert.fail("Expected revert not received")
      } catch(err) {
        assert.equal(err.reason,
          "Cannot set a proxy implementation to a non-contract address")
      }
    })
  })
})
