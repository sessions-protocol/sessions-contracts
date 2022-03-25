// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ICollectModule} from "./ICollectModule.sol";
import {ILensHub} from "./ILensHub.sol";
import {ISessions, SessionType, Date} from "../../interface/ISessions.sol";

struct ProfilePublicationData {
    address user;
    uint32 sessionTypeId;
}

contract CollectModule is ICollectModule {
    ISessions public sessions;
    ILensHub public lensHub;
    mapping(uint256 => mapping(uint256 => ProfilePublicationData))
        internal _dataByPublicationByProfile;

    constructor(address _lensHub, address _sessions) {
        lensHub = ILensHub(_lensHub);
        sessions = ISessions(_sessions);
    }

    modifier onlyHub() {
        require(msg.sender == address(lensHub), "!lensHub");
        _;
    }

    function setSessions(address _sessions) public onlyHub {
        sessions = ISessions(_sessions);
    }

    function setLensHub(address _lensHub) public onlyHub {
        lensHub = ILensHub(_lensHub);
    }

    function initializePublicationCollectModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external returns (bytes memory) {
        address user = lensHub.ownerOf(profileId);
        uint32 id = _createSessionType(user, data);
        _dataByPublicationByProfile[profileId][pubId].user = user;
        _dataByPublicationByProfile[profileId][pubId].sessionTypeId = id;
        return data;
    }

    function _createSessionType(address user, bytes calldata data)
        internal
        returns (uint32 id)
    {
        (
            address recipient,
            uint32 availabilityId,
            uint8 durationInSlot,
            string memory title,
            string memory description,
            address token,
            uint256 amount
        ) = abi.decode(
                data,
                (address, uint32, uint8, string, string, address, uint256)
            );
        return
            sessions.createSessionType(
                user,
                recipient,
                availabilityId,
                durationInSlot,
                title,
                description,
                token,
                amount
            );
    }

    function processCollect(
        uint256 referrerProfileId,
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external {
        (Date memory date, uint8[] memory slots) = abi.decode(
            data,
            (Date, uint8[])
        );
        uint32 sessionTypeId = _dataByPublicationByProfile[profileId][pubId]
            .sessionTypeId;
        address seller = lensHub.ownerOf(profileId);
        require(
            _dataByPublicationByProfile[profileId][pubId].user == seller,
            "!seller"
        );
        sessions.book(seller, collector, date, slots, sessionTypeId);
    }
}
