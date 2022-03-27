// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;

interface ILensHubNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
}
