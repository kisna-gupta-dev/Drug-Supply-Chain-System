require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    viaIR: true,
  },
 
  networks: {
    // zkEVMTestnet: {
    //   url: process.env.RPC_URL_zkEVM,
    //   accounts: [process.env.PRIVATE_KEY],
    // },
    // sepolia: {
    //   url: process.env.RPC_URL_SEPOLIA,
    //   accounts: [process.env.PRIVATE_KEY],
    // },
    ganache:{
      url: process.env.RPC_URL_GANACHE,
      accounts: [process.env.PRIVATE_KEY],
      chainId : 1337,
    }
    // localhost:{
    //   url :"http://127.0.0.1:8545/",
    //   chainId : 31337,    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    token: "ETH",
    gasPriceApi: process.env.ETHERSCAN_API_KEY,
  },
};
