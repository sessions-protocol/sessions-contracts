// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./interface/ISessionProfile.sol";
import "hardhat/console.sol";

error HandleLengthInvalid();
error HandleContainsInvalidCharacters();
error HandleTaken();

contract SessionProfile is ERC721EnumerableUpgradeable {
    uint8 internal constant MAX_HANDLE_LENGTH = 31;
    uint256 internal _profileIdCounter;
    mapping(uint256 => ProfileStruct) internal _profileById;
    mapping(bytes32 => uint256) internal _profileIdByHandleHash;
    mapping(address => uint256[]) internal _profileIdsByAddress;

    event ProfileCreated(
        uint256 indexed profileId,
        address indexed to,
        string handle,
        string imageURI,
        uint256 timestamp
    );

    function createProfile(string calldata handle, string calldata imageURI)
        external
    {
        _validateHandle(handle);

        bytes32 handleHash = keccak256(bytes(handle));
        if (_profileIdByHandleHash[handleHash] != 0) revert HandleTaken();

        uint256 profileId = ++_profileIdCounter;
        _profileById[profileId].handle = handle;
        _profileById[profileId].imageURI = imageURI;

        _profileIdByHandleHash[handleHash] = profileId;
        _profileIdsByAddress[msg.sender].push(profileId);

        _mint(msg.sender, profileId);

        emit ProfileCreated(
            profileId,
            msg.sender,
            handle,
            imageURI,
            block.timestamp
        );
    }

    function getUserProfiles(address user)
        public
        view
        returns (ProfileWithId[] memory profiles)
    {
        uint256[] memory profileIds = _profileIdsByAddress[user];
        ProfileWithId[] memory _profiles = new ProfileWithId[](
            profileIds.length
        );
        for (uint256 i = 0; i < profileIds.length; i++) {
            uint256 id = profileIds[i];
            _profiles[i].id = id;
            _profiles[i].handle = _profileById[id].handle;
            _profiles[i].imageURI = _profileById[id].imageURI;
        }
        profiles = _profiles;
    }

    function getProfileById(uint256 id)
        public
        view
        returns (ProfileStruct memory profile)
    {
        profile = _profileById[id];
    }

    function getProfileByHandle(string memory handle)
        public
        view
        returns (ProfileWithId memory profile)
    {
        bytes32 handleHash = keccak256(bytes(handle));
        uint256 id = _profileIdByHandleHash[handleHash];
        profile.id = id;
        profile.handle = _profileById[id].handle;
        profile.imageURI = _profileById[id].imageURI;
    }

    function _validateHandle(string calldata handle) private pure {
        bytes memory byteHandle = bytes(handle);
        if (byteHandle.length == 0 || byteHandle.length > MAX_HANDLE_LENGTH)
            revert HandleLengthInvalid();

        for (uint256 i = 0; i < byteHandle.length; ++i) {
            if (
                (byteHandle[i] < "0" ||
                    byteHandle[i] > "z" ||
                    (byteHandle[i] > "9" && byteHandle[i] < "a")) &&
                byteHandle[i] != "."
            ) revert HandleContainsInvalidCharacters();
        }
    }
}
