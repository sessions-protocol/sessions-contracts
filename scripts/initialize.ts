import hre from "hardhat";
import { utils } from "ethers";

const ethers = hre.ethers;

async function main() {
  const { deployer } = await hre.getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const Sessions = utils.getAddress(
    "0xD25bB78d4750458BC564b21FbfF3566294FAF560"
  );

  const sessionNFTImpl = utils.getAddress(
    "0x69129Ea5Ef74C2c2F769603a594017Ec8a4B5B26"
  );

  const contract = new hre.ethers.Contract(
    Sessions,
    require("../artifacts/contracts/Sessions.sol/Sessions.json").abi,
    signer
  );

  const calldata = [sessionNFTImpl, deployer];
  const tx = await contract.initialize(...calldata);
  await tx.wait();
  console.log(tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
