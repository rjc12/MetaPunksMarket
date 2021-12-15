require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require('hardhat-log-remover'); // npx hardhat remove-logs
let secret = require('./secret');
const { API_URL, PRIVATE_KEY } = process.env;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000000, // default: 200
          },
        }
      },
    ],
  },
  defaultNetwork: "rinkeby",
   networks: {
     hardhat: {},
     rinkeby: {
      url: "https://eth-rinkeby.alchemyapi.io/v2/4mckGjDSxLj2o-LC1cWXrDWinsiUA0pk",
      accounts: [`0xe5d23442ab5dd71a32a9a8ff2b9a26a315fd30b2b185581a7b8248b6ada4071d`]
   }
   },
   gasReporter: {
     //enabled: (process.env.REPORT_GAS) ? true : false,
     coinmarketcap: secret.coinMarketCap,
     currency: 'USD',
     gasPrice: 150,
     showTimeSpent: true,
   },
   etherscan: {
    // Your API key for Etherscan
  // Obtain one at https://etherscan.io/
  apiKey: "3SBPY4PF1ITK3FRM338Z5ZNS8M2UUY8SCF"
 }
};
