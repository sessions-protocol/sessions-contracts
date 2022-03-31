// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;

struct SessionType {
    address payable recipient;
    uint8 durationInSlot;
    uint32 openBookingDeltaDays;
    string title;
    string description;
    bool archived;
    bool locked;
    bool validateFollow;
    address token;
    uint256 amount;
    address sessionNFT;
    uint256 availabilityId;
    uint256 profileId;
}

struct SessionAvailability {
    uint256 date;
    uint256 availableSlot;
}

struct SessionTypeData {
    address payable recipient;
    uint8 durationInSlot;
    uint32 openBookingDeltaDays;
    string title;
    string description;
    address token;
    uint256 amount;
    uint256 availabilityId;
    bool locked;
    bool validateFollow;
}

struct Session {
    uint256 sessionTypeId;
    string title;
    uint256 start;
    uint256 end;
    string contentURI;
}

struct Availability {
    uint256[7] availableSlots;
    bool archived;
    string name;
}


interface ISessions {
    function book(
        uint256 timestamp,
        uint256 sessionTypeId
    ) external payable;

    function createSessionType(
        uint256 profileId,
        SessionTypeData calldata data
    ) external returns (uint256 sessionTypeId);

    function getContentURI(uint256 sessionTypeId, uint256 sessionNFTId)
        external
        view
        returns (string memory);

    function onSessionNFTTransfer(
        uint256 sessionTypeId,
        uint256 followNFTId,
        address from,
        address to
    ) external;
}
