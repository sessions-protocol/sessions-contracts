import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SessionProfile, Sessions } from "../typechain";

describe("Sessions Profile", function () {
  let sessions: Sessions;
  let sessionProfile: SessionProfile;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  const user1Profile = {
    handle: "user1",
    imgURI: "User1ImgURI",
  };
  this.beforeAll(async () => {
    const Sessions = await ethers.getContractFactory("Sessions");
    const SessionProfile = await ethers.getContractFactory("SessionProfile");
    sessionProfile = await SessionProfile.deploy();
    await sessionProfile.deployed();
    sessions = await Sessions.deploy(sessionProfile.address);
    await sessions.deployed();
    [user1, user2] = await ethers.getSigners();

    await sessionProfile.createProfile(
      user1Profile.handle,
      user1Profile.imgURI,
      { from: user1.address }
    );
  });
  it("can get user's profile", async function () {
    const r_user1Profiles = await sessionProfile.getUserProfiles(user1.address);
    expect(r_user1Profiles.length).eq(1);
    const r_user1Profile = r_user1Profiles[0];
    expect(r_user1Profile.id).eq(1);
    expect(r_user1Profile.handle).eq(user1Profile.handle);
    expect(r_user1Profile.imageURI).eq(user1Profile.imgURI);
  });
  it("can get profile by profileId", async function () {
    const r_byId = await sessionProfile.getProfileById(1);
    expect(r_byId.handle).eq(user1Profile.handle);
  });
  it("can get profile by handle", async function () {
    const r_byHandle = await sessionProfile.getProfileByHandle(
      user1Profile.handle
    );
    expect(r_byHandle.id).eq(1);
    expect(r_byHandle.handle).eq(user1Profile.handle);
  });
  it("should be globally unique for handle", async function () {
    await expect(
      sessionProfile
        .connect(user2)
        .createProfile(user1Profile.handle, "", { from: user2.address })
    ).to.be.revertedWith("HandleTaken()");
  });
  it("should validate handle", async function () {
    await expect(
      sessionProfile
        .connect(user2)
        .createProfile("", "", { from: user2.address })
    ).to.be.revertedWith("HandleLengthInvalid()");
    await expect(
      sessionProfile
        .connect(user2)
        .createProfile("x".repeat(32), "", { from: user2.address })
    ).to.be.revertedWith("HandleLengthInvalid()");
    await expect(
      sessionProfile
        .connect(user2)
        .createProfile("Abc", "", { from: user2.address })
    ).to.be.revertedWith("HandleContainsInvalidCharacters()");
  });

  it("should be able to check owner of profileId", async () => {
    expect(await sessionProfile.ownerOf(1)).eq(user1.address)
  });
});
