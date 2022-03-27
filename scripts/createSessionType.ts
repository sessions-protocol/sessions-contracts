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
    {
      recipient: deployer,
      durationInSlot: 10,
      availabilityId: 1,
      title: "english 1h",
      description: "zoom meeting",
      contentURI: "",
      token: "0x0000000000000000000000000000000000000000",
      amount: "100000000000000000",
      locked: false,
    },
  ];
  const tx = await sessionsContract.createSessionType(...calldata);
  await tx.wait();
  console.log(tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
