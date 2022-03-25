import { expect } from "chai";
import { ethers  } from "hardhat";
import { Sessions } from "../typechain";

describe("Sessions", function () {
  let sessions: Sessions
  this.beforeAll(async () => {
    const Sessions = await ethers.getContractFactory("Sessions");
    sessions = await Sessions.deploy();
    await sessions.deployed();
  })
  it("isSlotsAvailable", async function () {
    const v = parseInt('101', 2)
    expect(await sessions.isSlotsAvailable(v, 0, 1)).false;
    expect(await sessions.isSlotsAvailable(v, 1, 1)).true;
    expect(await sessions.isSlotsAvailable(v, 2, 2)).false;
  });
  it("lock", async function () {
    await sessions.lockSlots('2022-01-01', 0, 3)
    await expect(sessions.lockSlots('2022-01-01', 1, 2)).to.be.revertedWith('slots are already taken');
    await expect(sessions.lockSlots('2022-01-01', 1, 2)).to.be.revertedWith('slots are already taken');
  });
});
