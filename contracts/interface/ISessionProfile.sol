// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;

struct ProfileStruct {
    string handle;
    string imageURI;
}
struct ProfileWithId {
    uint256 id;
    string handle;
    string imageURI;
}

interface ISessionProfile {
    function createProfile(
        address to,
        string calldata handle,
        string calldata imageURI
    ) external;

    function getUserProfiles(address user)
        external
        view
        returns (uint256[] memory profileIds, ProfileStruct[] memory profiles);

    function getProfileById(uint256 id)
        external
        view
        returns (ProfileStruct memory profile);

    function getProfileByHandle(string memory handle)
        external
        view
        returns (ProfileStruct memory profile);

    function ownerOf(uint256 tokenId) external view returns (address);
}
