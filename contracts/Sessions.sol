// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";
import "./DateTime.sol";
import "./Manager.sol";
import "./AvailabilityStore.sol";
import "./SessionTypeStore.sol";
import "./Treasury.sol";

contract Sessions is Manager, SessionTypeStore, AvailabilityStore, Treasury {
    using SafeERC20 for IERC20;

    // user -> date -> slots, 6 minutes per slot, 240 bits for a day
    // 0 -> unlock, 1 -> locked
    mapping(address => mapping(uint32 => uint256)) private calendarByUserByDate;

    constructor(address _gov, address manager) {
        require(_gov != address(0), "!gov");
        whitelist(manager, true);
        gov = _gov;
    }

    modifier onlyProfileOwner() {
        // TODO: check if msg.sender have a user
        // require(msg.sender != , "!userOwner");
        _;
    }

    modifier onlyInFeature(Date memory date) {
        uint32 timestamp = DateTime.toTimestamp(date);
        require(timestamp > block.timestamp, "!inFeature");
        _;
    }

    modifier validSlotIndex(uint8[] calldata slots) {
        uint256 len = slots.length;
        require(len <= 240, "only handle slots in a day");
        uint8[] memory uniqCheck = new uint8[](len);
        for (uint8 i = 0; i < len; i++) {
            uint8 slot = slots[i];
            require(uniqCheck[slot] == 0, "slots must be unique");
            uniqCheck[slot] = 1;
            require(slot < 240, "slot index out of range");
        }
        _;
    }

    modifier userGuard(address user) {
        // TODO: check if user is allowed to access this user
        // require(msg.sender == , "!Authorized");
        _;
    }

    function book(
        address seller,
        address buyer,
        Date calldata date,
        uint8[] calldata slots,
        uint32 sessionTypeId
    ) external validSlotIndex(slots) onlyInFeature(date) userGuard(seller) {
        uint32 timestamp = DateTime.toTimestamp(date);
        uint256 calendar = calendarByUserByDate[seller][timestamp];
        SessionType memory sessionType = getSessionType(seller, sessionTypeId);
        Availability memory availability = getAvailability(
            seller,
            sessionType.availabilityId
        );
        uint256 availableSlots = availability.availableSlots[
            DateTime.getWeekday(timestamp)
        ];
        // lock slots
        calendarByUserByDate[seller][timestamp] = lockSlots(
            calendar,
            availableSlots,
            slots
        );
        address recipient = sessionType.recipient;
        uint256 amount = sessionType.amount;
        address token = sessionType.token;
        uint256 treasuryAmount = (amount * treasuryFee) / BPS_MAX;
        uint256 adjustedAmount = amount - treasuryAmount;

        IERC20(token).safeTransferFrom(buyer, recipient, adjustedAmount);
        if (treasuryAmount > 0)
            IERC20(token).safeTransferFrom(buyer, treasury, treasuryAmount);
    }

    function isSlotsAvailable(
        uint256 calendar,
        uint256 availabilityByUserByDay,
        uint8[] calldata slots
    ) internal pure returns (bool) {
        uint256 len = slots.length;
        for (uint256 i = 0; i <= len; i++) {
            uint8 index = slots[i];
            if (
                isBitSet(calendar, index) ||
                !isBitSet(availabilityByUserByDay, index)
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
        uint256 availabilityByUserByDay,
        uint8[] calldata slots
    ) internal pure validSlotIndex(slots) returns (uint256 calendar) {
        require(
            isSlotsAvailable(_calendar, availabilityByUserByDay, slots),
            "slots are already taken"
        );
        uint256 len = slots.length;
        for (uint256 i = 0; i <= len; i++) {
            _calendar | (uint256(1) << slots[i]);
        }
        calendar = _calendar;
    }
}
