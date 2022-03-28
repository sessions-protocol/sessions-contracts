// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;

import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "./interface/ISessions.sol";

contract SessionNFT is ERC721EnumerableUpgradeable {
    address public immutable SESSIONS;

    uint256 internal _profileId;
    uint256 internal _sessionTypeId;
    uint256 internal _tokenIdCounter;

    bool private _initialized;

    constructor(address _sessions) {
        SESSIONS = _sessions;
    }

    function initialize(
        uint256 profileId,
        uint256 sessionTypeId,
        string calldata _name,
        string calldata _symbol
    ) external initializer {
        _profileId = profileId;
        _sessionTypeId = sessionTypeId;
        __ERC721_init(_name, _symbol);
    }

    function mint(address to) external returns (uint256 tokenId){
        require(msg.sender == SESSIONS, "SessionNFT: only the hub can mint");
        uint256 tokenId = ++_tokenIdCounter;
        _mint(to, tokenId);

    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return ISessions(SESSIONS).getContentURI(_sessionTypeId, tokenId);
    }

    /**
     * @dev Upon transfers, we emit the transfer event in the hub.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
        ISessions(SESSIONS).onSessionNFTTransfer(_sessionTypeId, tokenId, from, to);
    }
}
