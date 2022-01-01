const networks = require('./networks')

module.exports = {
  networks,
  contracts_directory: "0.5-contracts",
  compilers: {
    solc: {
      version: "0.5.8",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
}
