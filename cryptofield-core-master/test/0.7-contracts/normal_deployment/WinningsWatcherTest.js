const WinningsWatcher = artifacts.require("WinningsWatcher");
const ERC20Test = artifacts.require("ERC20Test");

contract("WinningsWatcher", async (acc) => {
  const MAX_WETH = web3.utils.toWei("10", "ether");
  const RACE_ID = web3.utils.toHex("race_id");
  const HORSE_ID = 123;

  let transferAmount = web3.utils.toWei("0.005", "ether");
  let winningsWatcher, erc20;

  beforeEach("setup instances", async () => {
    erc20 = await ERC20Test.new(MAX_WETH);
    winningsWatcher = await WinningsWatcher.new(erc20.address);
  });

  describe("sendWinnings", async () => {
    describe("valid transfer", async () => {
      beforeEach("approve weth", async () => {
        erc20.approve(winningsWatcher.address, MAX_WETH);
      });

      it("should transfer WETH to user", async () => {
        let preBalance = await erc20.balanceOf(acc[0]);
        await winningsWatcher.sendWinnings(
          RACE_ID,
          acc[1],
          HORSE_ID,
          transferAmount
        );

        let currentBalance = await erc20.balanceOf(acc[0]);
        assert.isTrue(Number(currentBalance) < Number(preBalance));
      });

      it("should be able to make transfers to same user with different horse ID", async () => {
        let preBalance = await erc20.balanceOf(acc[0]);
        await winningsWatcher.sendWinnings(
          RACE_ID,
          acc[1],
          HORSE_ID,
          transferAmount
        );
        await winningsWatcher.sendWinnings(
          RACE_ID,
          acc[1],
          321,
          transferAmount
        );

        let currentBalance = await erc20.balanceOf(acc[0]);
        assert.isTrue(Number(currentBalance) < Number(preBalance));
      });

      it("should emit event when transfer is made", async () => {
        let tx = await winningsWatcher.sendWinnings(
          RACE_ID,
          acc[1],
          HORSE_ID,
          transferAmount
        );

        let log = tx.receipt.logs[0];

        assert.equal(log.event, "WinningsTransfer");
      });
    });

    describe("reverts", async () => {
      beforeEach("approve weth", async () => {
        erc20.approve(winningsWatcher.address, MAX_WETH);
      });

      it("should revert if transfer for user in race has been made", async () => {
        await winningsWatcher.sendWinnings(
          RACE_ID,
          acc[1],
          HORSE_ID,
          transferAmount
        );

        try {
          await winningsWatcher.sendWinnings(
            RACE_ID,
            acc[1],
            HORSE_ID,
            transferAmount
          );
        } catch (e) {
          assert.equal(e.reason, "WinningsWatcher: user has been paid already");
        }
      });
    });
  });
});
