require("@nomicfoundation/hardhat-toolbox");

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com/",
      accounts: ["f389c0a3163c73e4a0476a96d292c06cc9b1ff8be989b7273bb72c577dfed494"]
    }
  }
};
