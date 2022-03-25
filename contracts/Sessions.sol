// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";
import "./DateTime.sol";
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

    constructor(address _gov, address manager) {
        require(_gov != address(0), "!gov");
        whitelistManager(manager, true);
        gov = _gov;
    }

    function createAvailability(
        address user,
        string memory name,
        uint256[7] calldata availableSlots
    ) external onlyManagerOrUser(user) {
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
        onlyManagerOrUser(user)
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
    ) external onlyManagerOrUser(user) {
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
    )
        external
        onlyManagerOrUser(user)
        returns (SessionType memory sessionType)
    {
        sessionType = SessionType({
            id: uint32(sessionTypeByUser[user].length) + 1,
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
    }

    function archivedSessionType(address user, uint32 id)
        external
        onlyManagerOrUser(user)
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

    function updateSessionType(
        address user,
        address recipient,
        uint32 id,
        uint32 availabilityId,
        uint8 durationInSlot,
        string calldata title,
        string calldata description,
        address token,
        uint256 amount
    ) external onlyManagerOrUser(user) {
        // TODO: validate input data
        require(id <= sessionTypeByUser[user].length, "!availabilityId");
        uint32 i = id - 1;
        sessionTypeByUser[user][i] = SessionType({
            id: id,
            recipient: recipient,
            availabilityId: availabilityId,
            durationInSlot: durationInSlot,
            title: title,
            description: description,
            archived: sessionTypeByUser[user][i].archived,
            token: token,
            amount: amount
        });
    }

    function book(
        address seller,
        address buyer,
        Date calldata date,
        uint8[] calldata slots,
        uint32 sessionTypeId
    ) external validSlotIndex(slots) onlyInFeature(date) {
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
}
