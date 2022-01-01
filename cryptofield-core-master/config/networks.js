require("babel-register");
require("babel-polyfill");

if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}

const HDWalletProvider = require("@truffle/hdwallet-provider");
const mnemonic = process.env.mnemonic;

module.exports = {
  development: {
    host: "127.0.0.1",
    port: 8545,
    network_id: "*",
  },
  goerli: {
    provider: () => {
      return new HDWalletProvider({
        mnemonic: { phrase: mnemonic },
        providerOrUrl: "https://goerli.zed.run/rpc",
        numberOfAddresses: 10,
      });
    },
    network_id: 5,
  },
  mumbai: {
    provider: () => {
      return new HDWalletProvider({
        mnemonic: { phrase: mnemonic },
        providerOrUrl: "https://rpc-mumbai.matic.today",
        numberOfAddresses: 10,
      });
    },
    network_id: 80001,
  },
  matic: {
    provider: () => {
      return new HDWalletProvider({
        mnemonic: { phrase: mnemonic },
        providerOrUrl: "https://rpc-mainnet.matic.network",
        numberOfAddresses: 10,
      });
    },
    network_id: 137,
  },
  mainnet: {
    provider: () => {
      return new HDWalletProvider({
        mnemonic: { phrase: mnemonic },
        providerOrUrl:
          "https://mainnet.infura.io/v3/" + process.env.infura_token,
        numberOfAddresses: 10,
      });
    },
    network_id: 1,
  },
};
