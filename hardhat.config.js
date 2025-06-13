require('dotenv').config();
require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');


const { PRIVATE_KEY, MAINNET_RPC_URL, ETHERSCAN_API_KEY } = process.env;

if (!MAINNET_RPC_URL || !PRIVATE_KEY) {
  console.error("❌ ENV variables missing:");
  console.log("MAINNET_RPC_URL:", MAINNET_RPC_URL);
  console.log("PRIVATE_KEY:", PRIVATE_KEY ? "✅ loaded" : "❌ missing");
  process.exit(1);
}

module.exports = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
      forking: {
        url: MAINNET_RPC_URL,
      },
    },
    mainnet: {
      url: MAINNET_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
};
