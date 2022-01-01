const networks = require("./networks");

module.exports = {
  networks,
  contracts_directory: "0.7-contracts",
  compilers: {
    solc: {
      version: "0.7.6",
      parser: "solcjs",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
};
