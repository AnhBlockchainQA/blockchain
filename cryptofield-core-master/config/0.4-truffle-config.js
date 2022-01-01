const networks = require('./networks')

module.exports = {
  networks,
  contracts_directory: "0.4-contracts",
  compilers: {
    solc: {
      version: "0.4.24",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
}