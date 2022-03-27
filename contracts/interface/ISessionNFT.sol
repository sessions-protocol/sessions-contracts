// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;

interface ISessionNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function mint(address to) external returns (uint256 tokenId);
    function initialize(
        uint256 profileId,
        uint256 sessionTypeId,
        string calldata _name,
        string calldata _symbol
    ) external;
}
