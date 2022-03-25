import { ethers } from "hardhat";

async function main() {
  const Sessions = await ethers.getContractFactory("Sessions");
  const [gov] = await ethers.getSigners();
  const sessions = await Sessions.deploy(gov.address);

  await sessions.deployed();

  console.log("sessions deployed to:", sessions.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
