import hre from "hardhat";
import { utils } from "ethers";

const ethers = hre.ethers;

async function main() {
  const { deployer } = await hre.getNamedAccounts();
  const signer = await ethers.getSigner(deployer);

  const Sessions = utils.getAddress(
    "0x6dc0424c5beb6bfadd150633e2e99522ddc0802d"
  );

  const sessionsContract = new hre.ethers.Contract(
    Sessions,
    require("../artifacts/contracts/Sessions.sol/Sessions.json").abi,
    signer
  );

  const calldata = [
    "1127",
    "workday",
    [
      "0",
      "100433627766186892221372630771322662656457095490707140902912",
      "100433627766186892221372630771322662656457095490707140902912",
      "100433627766186892221372630771322662656457095490707140902912",
      "100433627766186892221372630771322662656457095490707140902912",
      "100433627766186892221372630771322662656457095490707140902912",
      "0",
    ],
  ];
  const tx = await sessionsContract.createAvailability(...calldata);
  await tx.wait();
  console.log(tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
