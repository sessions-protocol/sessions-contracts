// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

struct SessionType {
    uint32 id;
    address recipient;
    uint8 durationInSlot;
    string title;
    string description;
    bool archived;
    uint32 availabilityId;
    address token;
    uint256 amount;
}

struct Availability {
    uint32 id;
    uint256[7] availableSlots;
    bool archived;
    string name;
}

struct Date {
    uint16 year;
    uint8 month;
    uint8 day;
}

interface ISessions {
    function book(
        address seller,
        address buyer,
        Date calldata date,
        uint8[] calldata slots,
        uint32 sessionTypeId
    ) external;

    function createSessionType(
        address user,
        address recipient,
        uint32 availabilityId,
        uint8 durationInSlot,
        string calldata title,
        string calldata description,
        address token,
        uint256 amount
    ) external returns (SessionType memory);
}
