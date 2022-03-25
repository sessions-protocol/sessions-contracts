// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";
import "./Manager.sol";
import "./Treasury.sol";
import "./interface/ISessions.sol";

contract Sessions is ISessions, Manager, Treasury {
    using SafeERC20 for IERC20;

    // user -> date -> slots, 6 minutes per slot, 240 bits for a day
    // 0 -> unlock, 1 -> locked
    mapping(address => mapping(uint32 => uint256)) private calendarByUserByDate;
    mapping(address => SessionType[]) private sessionTypeByUser;
    mapping(address => Availability[]) private availabilityByUser;

    constructor(address _gov) {
        require(_gov != address(0), "!gov");
        gov = _gov;
    }

    function createAvailability(
        address user,
        string memory name,
        uint256[7] calldata availableSlots
    ) external onlyManagerOrSelf(user) {
        // TODO: validate input data
        availabilityByUser[user].push(
            Availability({
                id: uint32(availabilityByUser[user].length) + 1,
                availableSlots: availableSlots,
                name: name,
                archived: false
            })
        );
    }

    function archivedAvailability(address user, uint32 id)
        external
        onlyManagerOrSelf(user)
    {
        require(id <= availabilityByUser[user].length, "!availabilityId");
        uint32 i = id - 1;
        require(
            availabilityByUser[user][i].archived == false,
            "already archived"
        );
        availabilityByUser[msg.sender][i].archived = true;
    }

    function getAvailability(address user, uint32 id)
        public
        view
        returns (Availability memory)
    {
        require(id <= availabilityByUser[user].length, "!availabilityId");
        return availabilityByUser[user][id - 1];
    }

    function updateAvailability(
        address user,
        uint32 id,
        string calldata name,
        uint256[7] calldata availableSlots
    ) external onlyManagerOrSelf(user) {
        // TODO: validate input data
        require(id <= availabilityByUser[user].length, "!availabilityId");
        uint32 i = id - 1;
        availabilityByUser[user][i] = Availability({
            id: id,
            availableSlots: availableSlots,
            name: name,
            archived: availabilityByUser[user][i].archived
        });
    }

    modifier onlyInFeature(Date memory date) {
        uint32 timestamp = _toTimestamp(date);
        require(timestamp > block.timestamp, "!inFeature");
        _;
    }

    function _validSlotIndex(uint8[] calldata slots)
        internal
        pure
        returns (bool)
    {
        uint256 len = slots.length;
        if (len > 240) return false;
        uint8[] memory uniqCheck = new uint8[](len);
        for (uint8 i = 0; i < len; i++) {
            uint8 slot = slots[i];
            if (uniqCheck[slot] == 0) return false;
            uniqCheck[slot] = 1;
            if (slot >= 240) return false;
        }
        return true;
    }

    function _validateSessionType(address user, SessionType memory sessionType)
        internal
        view
        returns (bool)
    {
        if (!tokenWhitelisted[sessionType.token]) return false;
        if (sessionType.recipient == address(0)) return false;
        if (sessionType.availabilityId >= availabilityByUser[user].length)
            return false;
        return true;
    }

    function createSessionType(
        address user,
        address recipient,
        uint32 availabilityId,
        uint8 durationInSlot,
        string calldata title,
        string calldata description,
        address token,
        uint256 amount
    ) external onlyManagerOrSelf(user) returns (uint32 sessionTypeId) {
        uint256 len = sessionTypeByUser[user].length;
        SessionType memory sessionType = SessionType({
            id: uint32(len) + 1,
            recipient: recipient,
            availabilityId: availabilityId,
            durationInSlot: durationInSlot,
            title: title,
            description: description,
            archived: false,
            token: token,
            amount: amount
        });
        require(_validateSessionType(user, sessionType), "invalid sessionType");

        sessionTypeByUser[user].push(sessionType);
        sessionTypeId = sessionType.id;
    }

    function archivedSessionType(address user, uint32 id)
        external
        onlyManagerOrSelf(user)
    {
        require(id <= sessionTypeByUser[user].length, "!availabilityId");
        uint32 i = id - 1;
        require(
            sessionTypeByUser[user][i].archived == false,
            "already archived"
        );
        sessionTypeByUser[msg.sender][i].archived = true;
    }

    function getSessionType(address user, uint32 id)
        public
        view
        returns (SessionType memory)
    {
        require(id <= sessionTypeByUser[user].length, "!availabilityId");
        return sessionTypeByUser[user][id - 1];
    }

    function updateSessionType(address user, SessionType calldata sessionType)
        external
        onlyManagerOrSelf(user)
    {
        uint256 len = sessionTypeByUser[user].length;
        uint256 index = sessionType.id - 1;
        require(index < len, "invalid id");
        require(_validateSessionType(user, sessionType), "invalid sessionType");
        sessionTypeByUser[user][index] = sessionType;
    }

    function book(
        address seller,
        address buyer,
        Date calldata date,
        uint8[] calldata slots,
        uint32 sessionTypeId
    ) external payable onlyManagerOrSelf(buyer) onlyInFeature(date) {
        uint32 timestamp = _toTimestamp(date);
        SessionType memory sessionType = getSessionType(seller, sessionTypeId);
        uint256 availableSlots = availabilityByUser[seller][
            sessionType.availabilityId - 1
        ].availableSlots[_getWeekday(timestamp)];
        // lock slots
        calendarByUserByDate[seller][timestamp] = _lockSlots(
            calendarByUserByDate[seller][timestamp],
            availableSlots,
            slots
        );
        _pay(buyer, sessionType);
    }

    function _pay(address buyer, SessionType memory sessionType) internal {
        address recipient = sessionType.recipient;
        uint256 amount = sessionType.amount;
        address token = sessionType.token;
        uint256 treasuryAmount = (amount * treasuryFee) / BPS_MAX;
        uint256 adjustedAmount = amount - treasuryAmount;

        IERC20(token).safeTransferFrom(buyer, recipient, adjustedAmount);
        if (treasuryAmount > 0)
            IERC20(token).safeTransferFrom(buyer, treasury, treasuryAmount);
    }

    function _lockSlots(
        uint256 _calendar,
        uint256 availabilityByUserByDay,
        uint8[] calldata slots
    ) internal pure returns (uint256 calendar) {
        require(_validSlotIndex(slots), "!validSlotIndex");
        require(
            _isSlotsAvailable(_calendar, availabilityByUserByDay, slots),
            "slots are already taken"
        );
        uint256 len = slots.length;
        for (uint256 i = 0; i <= len; i++) {
            _calendar | (uint256(1) << slots[i]);
        }
        calendar = _calendar;
    }

    function _isSlotsAvailable(
        uint256 calendar,
        uint256 availabilityByUserByDay,
        uint8[] calldata slots
    ) internal pure returns (bool) {
        uint256 len = slots.length;
        for (uint256 i = 0; i <= len; i++) {
            uint8 index = slots[i];
            if (
                _isBitSet(calendar, index) ||
                !_isBitSet(availabilityByUserByDay, index)
            ) {
                return false;
            }
        }
        return true;
    }

    function _isBitSet(uint256 data, uint8 index) internal pure returns (bool) {
        return (data >> index) & uint256(1) == 1;
    }

    function _isLeapYear(uint16 year) internal pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    function _getWeekday(uint256 timestamp) internal pure returns (uint8) {
        return uint8((timestamp / 86400 + 4) % 7);
    }

    function _toTimestamp(Date memory date)
        internal 
        pure
        returns (uint32 timestamp)
    {
        uint16 year = date.year;
        uint8 month = date.month;
        uint16 day = date.day;

        uint16 i;

        // Year
        for (i = 1970; i < year; i++) {
            if (_isLeapYear(i)) {
                timestamp += 31622400;
            } else {
                timestamp += 31536000;
            }
        }

        // Month
        uint8[12] memory monthDayCounts;
        monthDayCounts[0] = 31;
        if (_isLeapYear(year)) {
            monthDayCounts[1] = 29;
        } else {
            monthDayCounts[1] = 28;
        }
        monthDayCounts[2] = 31;
        monthDayCounts[3] = 30;
        monthDayCounts[4] = 31;
        monthDayCounts[5] = 30;
        monthDayCounts[6] = 31;
        monthDayCounts[7] = 31;
        monthDayCounts[8] = 30;
        monthDayCounts[9] = 31;
        monthDayCounts[10] = 30;
        monthDayCounts[11] = 31;

        for (i = 1; i < month; i++) {
            timestamp += 86400 * monthDayCounts[i - 1];
        }

        // Day
        timestamp += 86400 * (day - 1);
        return timestamp;
    }
}
