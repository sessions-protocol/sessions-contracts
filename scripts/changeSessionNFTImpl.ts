import hre from "hardhat";
import { utils } from "ethers";

const ethers = hre.ethers;

async function main() {
  const { deployer } = await hre.getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const Sessions = utils.getAddress(
    "0xf19C27C92EEA361F8e2FD246283CD058e4d78F00"
  );

  const sessionNFTImpl = utils.getAddress(
    "0x6dd7ff928757E839D0A8B11d59BDaD0AB2c0D584"
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