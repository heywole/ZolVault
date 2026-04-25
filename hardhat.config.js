require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    liteforge: {
      url: "https://liteforge.rpc.caldera.xyz",
      chainId: 4441,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
module.exports = {
  solidity: "0.8.20",
  networks: {
    liteforge: {
      url:      "https://liteforge.rpc.caldera.xyz",
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY.replace("0x","")}`] : [],
    },
  },
};
