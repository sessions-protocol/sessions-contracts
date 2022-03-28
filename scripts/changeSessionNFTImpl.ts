import hre from "hardhat";
import { utils } from "ethers";

const ethers = hre.ethers;

async function main() {
  const { deployer } = await hre.getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const Sessions = utils.getAddress(
    "0x54f6Fb3E799ed5A1FedeeF26E647801911BcB36d"
  );

  const sessionNFTImpl = utils.getAddress(
    "0xE520C6549f81d13903B17400b405f041Bb0936Ad"
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
