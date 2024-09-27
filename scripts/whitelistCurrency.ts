import hre from "hardhat";
import { utils } from "ethers";

const ethers = hre.ethers;

async function main() {
  const { deployer } = await hre.getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const Sessions = utils.getAddress(
    "0x82295BB8f16a5910303B214B5e4a844eF3091381"
  );

  const contract = new hre.ethers.Contract(
    Sessions,
    require("../artifacts/contracts/Sessions.sol/Sessions.json").abi,
    signer
  );

  /**
   * 0x326C977E6efc84E512bB9C30f76E30c160eD06FB  LIN
   * 0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F  DAI
   */
  const calldata = ["0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F", true];
  const tx = await contract.whitelistCurrency(...calldata);
  await tx.wait();
  console.log(tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
