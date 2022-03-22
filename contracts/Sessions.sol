//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./DateTime.sol";

contract Sessions {
    address private gov;

    // profile -> date -> slots, 6 minutes per slot, 240 bits for a day
    // 0 -> unlock, 1 -> locked
    mapping(address => mapping(uint32 => uint256)) private profileCalendar;

    // profile -> dayOfWeek -> available slots
    // 0 -> not available, 1 -> available for book
    // 0...6 -> Sunday...Saturday
    mapping(address => mapping(uint8 => uint256))
        private profileGeneralAvailability;
    mapping(address => uint256) private profilePrice;

    constructor(address _gov) {
        gov = _gov;
    }

    modifier onlyProfileOwner() {
        // TODO: check if msg.sender have a profile
        // require(msg.sender != , "!profileOwner");
        _;
    }

    modifier onlyInFeature(uint32 _date) {
        require(_date > block.timestamp, "!inFeature");
        _;
    }

    modifier validateSlotIndex(uint8[] calldata _slots) {
        uint256 len = _slots.length;
        for (uint256 i = 0; i < len; i++) {
            require(_slots[i] < 240, "slot index out of range");
        }
        _;
    }

    modifier userGuard(address _profile) {
        // TODO: check if user is allowed to access this profile
        // require(msg.sender == , "!Authorized");
        _;
    }

    function book(
        address _profile,
        DateTime.Date[] calldata _dates,
        uint8[][] calldata _slotsByDay
    ) external {
        uint256 dateLen = _dates.length;
        uint256 slotsByDayLen = _slotsByDay.length;
        require(dateLen == slotsByDayLen, "invalid dates/slots length");
        for (uint256 i = 0; i < dateLen; i++) {
            _book(_profile, DateTime.toTimestamp(_dates[i]), _slotsByDay[i]);
        }
    }

    function _book(
        address _profile,
        uint32 _date,
        uint8[] calldata _slots
    )
        internal
        validateSlotIndex(_slots)
        onlyInFeature(_date)
        userGuard(_profile)
    {
        uint256 calendar = profileCalendar[_profile][_date];
        uint256 generalAvailability = profileGeneralAvailability[_profile][
            DateTime.getWeekday(_date)
        ];
        // lock slots
        profileCalendar[_profile][_date] = lockSlots(
            calendar,
            generalAvailability,
            _slots
        );
    }

    function updatePricing(address _profile, uint256 price)
        external
        onlyProfileOwner
    {
        profilePrice[_profile] = price;
    }

    function updateGeneralAvailability(uint8 dayOfWeek, uint256 availableSlots)
        external
        onlyProfileOwner
    {}

    function reschedule(address _profile, uint256[] calldata slots)
        external
        onlyProfileOwner
    {}

    function isSlotsAvailable(
        uint256 _calendar,
        uint256 _profileGeneralAvailability,
        uint8[] calldata slots
    ) internal pure returns (bool) {
        uint256 len = slots.length;
        for (uint256 i = 0; i <= len; i++) {
            uint8 index = slots[i];
            if (
                isBitSet(_calendar, index) ||
                !isBitSet(_profileGeneralAvailability, index)
            ) {
                return false;
            }
        }
        return true;
    }

    function isBitSet(uint256 data, uint8 index) internal pure returns (bool) {
        return (data >> index) & uint256(1) == 1;
    }

    function lockSlots(
        uint256 _calendar,
        uint256 _profileGeneralAvailability,
        uint8[] calldata _slots
    ) internal pure validateSlotIndex(_slots) returns (uint256 calendar) {
        require(
            isSlotsAvailable(_calendar, _profileGeneralAvailability, _slots),
            "slots are already taken"
        );
        uint256 len = _slots.length;
        for (uint256 i = 0; i <= len; i++) {
            _calendar | (uint256(1) << _slots[i]);
        }
        calendar = _calendar;
    }
}
