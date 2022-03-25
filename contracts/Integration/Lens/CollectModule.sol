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
    ISessions private sessions;
    ILensHub private lensHub;
    address private gov;
    mapping(uint256 => mapping(uint256 => ProfilePublicationData))
        internal _dataByPublicationByProfile;

    constructor(
        address _lensHub,
        address _sessions,
        address _gov
    ) {
        lensHub = ILensHub(_lensHub);
        gov = _gov;
        sessions = ISessions(_sessions);
    }

    modifier onlyGov() {
        require(msg.sender == gov, "!gov");
        _;
    }

    function setGov(address _gov) public onlyGov {
        gov = _gov;
    }

    function setSessions(address _sessions) public onlyGov {
        sessions = ISessions(_sessions);
    }

    function setLensHub(address _lensHub) public onlyGov {
        lensHub = ILensHub(_lensHub);
    }

    function initializePublicationCollectModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external returns (bytes memory) {
        (
            uint8 durationInSlot,
            string memory title,
            string memory description,
            uint32 availabilityId,
            address token,
            uint256 amount
        ) = abi.decode(data, (uint8, string, string, uint32, address, uint256));
        address user = lensHub.ownerOf(profileId);
        SessionType memory sessionType = sessions.createSessionType(
            user,
            availabilityId,
            durationInSlot,
            title,
            description,
            token,
            amount
        );
        _dataByPublicationByProfile[profileId][pubId].user = user;
        _dataByPublicationByProfile[profileId][pubId]
            .sessionTypeId = sessionType.id;
        return data;
    }

    function processCollect(
        uint256 referrerProfileId,
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external {
        (Date memory date, uint8[] memory slots, uint32 sessionTypeId) = abi
            .decode(data, (Date, uint8[], uint32));
        address seller = lensHub.ownerOf(profileId);
        sessions.book(seller, collector, date, slots, sessionTypeId);
    }
}
