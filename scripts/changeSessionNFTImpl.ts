import hre from "hardhat";
import { utils } from "ethers";

const ethers = hre.ethers;

async function main() {
  const { deployer } = await hre.getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const Sessions = utils.getAddress(
    "0xF3bF2EA8Df05716a2e5EC39A747Cb54726a49fcE"
  );

  const sessionNFTImpl = utils.getAddress(
    "0x4da9f0bBe8701DB748496BF3eE1860c82E5Ce071"
  );

  const contract = new hre.ethers.Contract(
    Sessions,
    require("../artifacts/contracts/Sessions.sol/Sessions.json").abi,
    signer
  );

  const calldata = [sessionNFTImpl];
  const tx = await contract.setSessionNFTImpl(...calldata);
  await tx.wait();
  console.log(tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
