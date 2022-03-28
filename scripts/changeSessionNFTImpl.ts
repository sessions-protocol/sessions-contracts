import hre from "hardhat";
import { utils } from "ethers";

const ethers = hre.ethers;

async function main() {
  const { deployer } = await hre.getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const Sessions = utils.getAddress(
    "0x3a0494b31EE26705a8Cca6f42703Ec70E45b016a"
  );

  const sessionNFTImpl = utils.getAddress(
    "0xCc252ada0c8845fa5857A7C6Bb304B03f2b5F21D"
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
