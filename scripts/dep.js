require("@nomicfoundation/hardhat-ethers");
require("hardhat-deploy");
require("hardhat-deploy-ethers");
async function main() {

const Contract = await ethers.getContractFactory("Rocket");
const contract = await Contract.deploy();

contract = await hre.ethers.getContract('Rocket');
  console.log("Success! Contract was deployed to: ", contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });