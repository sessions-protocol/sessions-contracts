// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


import "./Treasury.sol";
import "./interface/ISessions.sol";
import "./interface/ISessionNFT.sol";
import "./interface/ILensHub.sol";
import "./interface/ILensHubNFT.sol";
import "./interface/IFollowModule.sol";

contract Sessions is ISessions, Treasury, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Strings for uint32;

    address public immutable LENS_HUB;
    address public sessionNFTImpl;

    string internal constant SESSION_NFT_NAME_INFIX = "-Session-";
    string internal constant SESSION_NFT_SYMBOL_INFIX = "-S-";
    uint256 constant SLOT_DURATION = 6 * 60; // 6 minutes

    // Profile -> date -> slots, 6 minutes per slot, 240 bits for a day
    // 0 -> unlock, 1 -> locked
    mapping(uint256 => mapping(uint256 => uint256)) public calendarByProfileByDate;
    mapping(uint256 => SessionType[]) public sessionTypeByProfile;
    mapping(uint256 => Availability[]) public availabilityByProfile;
    mapping(uint256 => mapping(uint256 => Session)) public sessionByProfileByNFT;
    constructor(address _lensHub, address _sessionNFTImpl, address _gov) {
        gov = _gov;
        LENS_HUB = _lensHub;
        sessionNFTImpl = _sessionNFTImpl;
    }

    modifier isOwenrOrDispatcher(uint256 lensProfileId) {
        address dispatcher = ILensHub(LENS_HUB).getDispatcher(lensProfileId);
        address owner = ILensHubNFT(LENS_HUB).ownerOf(lensProfileId);
        require(owner == msg.sender || msg.sender == dispatcher, "NOT_PROFILE_OWNER_OR_DISPATCHER");
        _;
    }

    function setSessionNFTImpl(address _sessionNFTImpl) external onlyGov {
        sessionNFTImpl = _sessionNFTImpl;
    }

    function createAvailability(
        uint256 lensProfileId,
        string memory name,
        uint256[7] calldata availableSlots
    ) external isOwenrOrDispatcher(lensProfileId) {
        // TODO: validate input data
        availabilityByProfile[lensProfileId].push(
            Availability({
                id: uint32(availabilityByProfile[lensProfileId].length) + 1,
                availableSlots: availableSlots,
                name: name,
                archived: false
            })
        );
    }

    function archivedAvailability(
        uint256 lensProfileId,
        uint32 id
    )
        external
        isOwenrOrDispatcher(lensProfileId)
    {
        require(id <= availabilityByProfile[lensProfileId].length, "!availabilityId");
        uint32 i = id - 1;
        require(
            availabilityByProfile[lensProfileId][i].archived == false,
            "already archived"
        );
        availabilityByProfile[lensProfileId][i].archived = true;
    }

    function getAvailability(uint256 lensProfileId, uint32 id)
        public
        view
        returns (Availability memory)
    {
        require(id <= availabilityByProfile[lensProfileId].length, "!availabilityId");
        return availabilityByProfile[lensProfileId][id - 1];
    }

    function updateAvailability(
        uint256 lensProfileId,
        uint32 id,
        string calldata name,
        uint256[7] calldata availableSlots
    )
        external
        isOwenrOrDispatcher(lensProfileId)
    {
        // TODO: validate input data
        require(id <= availabilityByProfile[lensProfileId].length, "!availabilityId");
        uint32 i = id - 1;
        availabilityByProfile[lensProfileId][i] = Availability({
            id: id,
            availableSlots: availableSlots,
            name: name,
            archived: availabilityByProfile[lensProfileId][i].archived
        });
    }


    function _validateSessionType(uint256 lensProfileId, SessionType memory sessionType)
        internal
        view
        returns (bool)
    {
        if (sessionType.token != address(0) && !tokenWhitelisted[sessionType.token]) return false;
        if (sessionType.recipient == address(0)) return false;
        if (sessionType.availabilityId > availabilityByProfile[lensProfileId].length)
            return false;
        return true;
    }

    function _checkFollowValidity(uint256 lensProfileId, address user) internal view {
        address followModule = ILensHub(LENS_HUB).getFollowModule(lensProfileId);
        if (followModule != address(0)) {
            IFollowModule(followModule).validateFollow(lensProfileId, user, 0);
        } else {
            address followNFT = ILensHub(LENS_HUB).getFollowNFT(lensProfileId);
            require(followNFT != address(0), "!followNFT"); 
            require(IERC721(followNFT).balanceOf(user) > 0, "!followNFT");
        }
    }

    function createSessionType(
        uint256 lensProfileId,
        SessionTypeData calldata data
    ) 
        external
        nonReentrant
        isOwenrOrDispatcher(lensProfileId)
        returns (uint32 sessionTypeId)
    {
        sessionTypeId = uint32(sessionTypeByProfile[lensProfileId].length) + 1;
        
        address sessionNFT = createSessionNFT(
            lensProfileId,
            sessionTypeId,
            data.title
        );

        SessionType memory sessionType = SessionType({
            id: sessionTypeId,
            recipient: data.recipient,
            durationInSlot: data.durationInSlot,
            availabilityId: data.availabilityId,
            openBookingDeltaDays: data.openBookingDeltaDays,
            title: data.title,
            description: data.description,
            archived: false,
            validateFollow: data.validateFollow,
            locked: data.locked,
            token: data.token,
            amount: data.amount,
            contentURI: data.contentURI,
            sessionNFT: sessionNFT
        });
        require(_validateSessionType(lensProfileId, sessionType), "invalid sessionType");

        sessionTypeByProfile[lensProfileId].push(sessionType);
    }

    function createSessionNFT(
        uint256 lensProfileId,
        uint32 sessionTypeId,
        string calldata title
    ) internal returns (address sessionNFT) {
        DataTypes.ProfileStruct memory profile = ILensHub(LENS_HUB).getProfile(lensProfileId);
        string memory handle = profile.handle;
        bytes4 firstBytes = bytes4(bytes(handle));

        string memory sessionNFTName = string(
            abi.encodePacked(handle, SESSION_NFT_NAME_INFIX, title)
        );
        string memory sessionNFTSymbol = string(
            abi.encodePacked(
                firstBytes,
                SESSION_NFT_SYMBOL_INFIX,
                sessionTypeId.toString()
            )
        );

        sessionNFT = Clones.clone(sessionNFTImpl);
        ISessionNFT(sessionNFT).initialize(
            lensProfileId,
            sessionTypeId,
            sessionNFTName,
            sessionNFTSymbol
        );
    }

    function getContentURI(uint256 lensProfileId, uint256 _sessionTypeId, uint256 sessionNFTId)
        external
        view
        override
        returns (string memory)
    {
        return sessionByProfileByNFT[lensProfileId][sessionNFTId].contentURI;
    }

    function onSessionNFTTransfer(
        uint256 lensProfileId,
        uint256 sessionTypeId,
        uint256 followNFTId,
        address from,
        address to
    ) external {
        SessionType memory sessionType = sessionTypeByProfile[lensProfileId][sessionTypeId - 1];
        require(msg.sender == sessionType.sessionNFT, "NOT_SESSION_NFT");
        require(sessionType.locked != true, "locked");
    }

    function archivedSessionType(
        uint32 id,
        uint256 lensProfileId
    )
        external
        isOwenrOrDispatcher(lensProfileId)
    {
        require(id <= sessionTypeByProfile[lensProfileId].length, "!sessionTypeId");
        sessionTypeByProfile[lensProfileId][id - 1].archived = true;
    }

    function getSessionType(uint256 lensProfileId, uint32 id)
        public
        view
        returns (SessionType memory)
    {
        require(id <= sessionTypeByProfile[lensProfileId].length, "!sessionTypeId");
        return sessionTypeByProfile[lensProfileId][id - 1];
    }

    function updateSessionType(
        uint256 lensProfileId,
        SessionType calldata sessionType
    )
        external
        isOwenrOrDispatcher(lensProfileId)
    {
        uint256 len = sessionTypeByProfile[lensProfileId].length;
        uint256 index = sessionType.id - 1;
        require(index < len, "invalid id");
        require(_validateSessionType(lensProfileId, sessionType), "invalid sessionType");
        sessionTypeByProfile[lensProfileId][index] = sessionType;
    }

    function book(
        uint256 lensProfileId,
        uint256 timestamp,
        uint32 sessionTypeId
    ) external payable nonReentrant {
        require(timestamp > block.timestamp, "!inFeature");

        SessionType memory sessionType = getSessionType(lensProfileId, sessionTypeId);
        require(
            sessionType.archived == false,
            "sessionType archived"
        );
        if (sessionType.validateFollow) {
            _checkFollowValidity(lensProfileId, msg.sender);
        }
        uint256 date = (timestamp / 86400) * 86400;
        uint8 startSlot = uint8((timestamp - date) / SLOT_DURATION);

        uint256 availableSlots = sessionType.availabilityId > 0 ? availabilityByProfile[lensProfileId][
            sessionType.availabilityId - 1
        ].availableSlots[_getWeekday(date)] : type(uint256).max;

        // lock slots
        calendarByProfileByDate[lensProfileId][date] = _lockSlots(
            calendarByProfileByDate[lensProfileId][date],
            availableSlots,
            startSlot,
            startSlot + sessionType.durationInSlot
        );
        _pay(sessionType);
        // mint
        uint256 sessionNFTId = ISessionNFT(sessionType.sessionNFT).mint(msg.sender);
        sessionByProfileByNFT[lensProfileId][sessionNFTId] = Session({
            sessionTypeId: sessionTypeId,
            title: sessionType.title,
            start: timestamp,
            end: timestamp + sessionType.durationInSlot * SLOT_DURATION,
            contentURI: sessionType.contentURI
        });
    }

    function _pay( SessionType memory sessionType) internal {
        address payable recipient = sessionType.recipient;
        uint256 amount = sessionType.amount;
        address token = sessionType.token;
        uint256 treasuryAmount = (amount * treasuryFee) / BPS_MAX;
        uint256 adjustedAmount = amount - treasuryAmount;
        if (token == address(0)) {
            require(msg.value >= amount, "!enough");
            // ETH
            Address.sendValue(recipient, adjustedAmount);
            if (treasuryAmount > 0) {
                Address.sendValue(treasury, treasuryAmount);
            }
        } else {
            // ERC20
            IERC20(token).safeTransferFrom(msg.sender, recipient, adjustedAmount);
            if (treasuryAmount > 0) {
                IERC20(token).safeTransferFrom(msg.sender, treasury, treasuryAmount);
            }
        }
    }

    function _lockSlots(
        uint256 _calendar,
        uint256 availabilityByProfileByDay,
        uint8 startSlot,
        uint8 endSlot
    ) internal pure returns (uint256 calendar) {
        require(endSlot < 241, "!validSlotIndex");
        uint8 len = endSlot - startSlot;
        for (uint8 i = 0; i <= len; i++) {
            uint8 index = startSlot + i;
            require(
                !_isBitSet(calendar, index) &&
                _isBitSet(availabilityByProfileByDay, index)
            , "!availableSlot");
            _calendar | (uint256(1) << index);
        }
        calendar = _calendar;
    }


    function _isBitSet(uint256 data, uint8 index) internal pure returns (bool) {
        return (data >> index) & uint256(1) == 1;
    }


    function _getWeekday(uint256 timestamp) internal pure returns (uint8) {
        return uint8((timestamp / 86400 + 4) % 7);
    }
}
