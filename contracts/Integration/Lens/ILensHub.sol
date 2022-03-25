// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

interface ILensHub {
    function ownerOf(uint256 tokenId) external view returns (address);
}
