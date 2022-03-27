// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;

struct SessionType {
    uint32 id;
    address payable recipient;
    uint8 durationInSlot;
    string title;
    string description;
    bool archived;
    bool locked;
    uint32 availabilityId;
    address token;
    uint256 amount;
    address sessionNFT;
    string contentURI;
}

struct SessionTypeData {
    address payable recipient;
    uint8 durationInSlot;
    uint32 availabilityId;
    string title;
    string description;
    string contentURI;
    address token;
    uint256 amount;
    bool locked;
}

struct Session {
    uint32 sessionTypeId;
    string title;
    uint256 start;
    uint256 end;
    string contentURI;
}

struct Availability {
    uint32 id;
    uint256[7] availableSlots;
    bool archived;
    string name;
}


interface ISessions {
    function book(
        uint256 lensProfileId,
        uint256 timestamp,
        uint32 sessionTypeId
    ) external payable;

    function createSessionType(
        uint256 lensProfileId,
        SessionTypeData calldata data
    ) external returns (uint32 sessionTypeId);

    function getContentURI(uint256 lensProfileId, uint256 _sessionTypeId, uint256 sessionNFTId)
        external
        view
        returns (string memory);

    function onSessionNFTTransfer(
        uint256 lensProfileId,
        uint256 sessionTypeId,
        uint256 followNFTId,
        address from,
        address to
    ) external;
}
