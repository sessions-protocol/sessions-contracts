// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.13;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Treasury.sol";
import "./interface/ISessions.sol";
import "./interface/ISessionNFT.sol";
import "./interface/ILensHub.sol";
import "./interface/ILensHubNFT.sol";
import "./interface/IFollowModule.sol";

contract Sessions is ISessions, Treasury, ReentrancyGuard, Initializable {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    address public immutable LENS_HUB;
    address public sessionNFTImpl;

    string internal constant SESSION_NFT_NAME_INFIX = "-Session-";
    string internal constant SESSION_NFT_SYMBOL_INFIX = "-S-";
    string internal constant SESSION_URL = "https://sessions.cyou/s/";
    
    uint256 constant SLOT_DURATION = 6 * 60; // 6 minutes

    // Profile -> date -> slots, 6 minutes per slot, 240 bits for a day
    // 0 -> unlock, 1 -> locked
    mapping(uint256 => mapping(uint256 => uint256)) public calendarByProfileByDate;
    SessionType[] public sessionTypes;
    mapping(uint256 => uint256) public sessionTypeOwner;
    mapping(uint256 => uint256[]) public sessionTypesOwnedByProfile;
    Availability[] public availabilitys;
    mapping(uint256 => uint256) public availabilityOwner;
    mapping(uint256 => uint256[]) public availabilitysOwnedByProfile;
    mapping(uint256 => mapping(uint256 => Session)) public sessionBySessionTypeByNFT;
    constructor(address _lensHub) {
        LENS_HUB = _lensHub;
    }

    modifier isOwenrOrDispatcher(uint256 lensProfileId) {
        _isLensProfileOwenrOrDispatcher(lensProfileId);
        _;
    }

    modifier isOwenrOrDispatcherBySessionTypeId(uint256 sessionTypeId) {
        uint256 lensProfileId = sessionTypeOwner[sessionTypeId];
        _isLensProfileOwenrOrDispatcher(lensProfileId);
        _;
    }

     modifier isOwenrOrDispatcherByAvailabilityId(uint256 availabilityId) {
        uint256 lensProfileId = availabilityOwner[availabilityId];
        _isLensProfileOwenrOrDispatcher(lensProfileId);
        _;
    }

    function initialize(address _sessionNFTImpl, address _gov) public initializer {
        sessionNFTImpl = _sessionNFTImpl;
        gov = _gov;
    }

    function _isLensProfileOwenrOrDispatcher(uint256 lensProfileId) internal {
        address dispatcher = ILensHub(LENS_HUB).getDispatcher(lensProfileId);
        address owner = ILensHubNFT(LENS_HUB).ownerOf(lensProfileId);
        require(owner == msg.sender || msg.sender == dispatcher, "NOT_PROFILE_OWNER_OR_DISPATCHER");
    }

    function setSessionNFTImpl(address _sessionNFTImpl) external onlyGov {
        sessionNFTImpl = _sessionNFTImpl;
    }

    function createAvailability(
        uint256 lensProfileId,
        string memory name,
        uint256[7] calldata availableSlots
    ) external isOwenrOrDispatcher(lensProfileId) {
        uint256 availabilityId = availabilitys.length + 1;
        availabilitys.push(
            Availability({
                availableSlots: availableSlots,
                name: name,
                archived: false
            })
        );
        availabilityOwner[availabilityId] = lensProfileId;
        availabilitysOwnedByProfile[lensProfileId].push(availabilityId);
    }

    function archivedAvailability(
        uint256 availabilityId
    )
        external
        isOwenrOrDispatcherByAvailabilityId(availabilityId)
    {
        availabilitys[availabilityId-1].archived = true;
    }

    function getAvailability(uint256 availabilityId)
        public
        view
        returns (Availability memory)
    {
        return availabilitys[availabilityId - 1];
    }

    function updateAvailability(
        uint256 availabilityId,
        string calldata name,
        uint256[7] calldata availableSlots,
        bool archived
    )
        external
        isOwenrOrDispatcherByAvailabilityId(availabilityId)
    {
        availabilitys[availabilityId - 1] = Availability({
            availableSlots: availableSlots,
            name: name,
            archived: archived
        });
    }


    function _validateSessionType(SessionType memory sessionType)
        internal
        view
        returns (bool)
    {
        if (sessionType.token != address(0) && !tokenWhitelisted[sessionType.token]) return false;
        if (sessionType.recipient == address(0)) return false;
        if (sessionType.availabilityId > 0 && availabilityOwner[sessionType.availabilityId] != sessionType.lensProfileId)
            return false;
        return true;
    }

    function checkFollowValidity(uint256 lensProfileId, address user) public view returns (bool) {
        address followModule = ILensHub(LENS_HUB).getFollowModule(lensProfileId);
        if (followModule != address(0)) {
            try IFollowModule(followModule).validateFollow(lensProfileId, user, 0) {
                return true;
            } catch (bytes memory) {
                return false;
            }
        } else {
            address followNFT = ILensHub(LENS_HUB).getFollowNFT(lensProfileId);
            if (followNFT == address(0)) return false;
            if (IERC721(followNFT).balanceOf(user) > 0) return true;
        }
    }

    function createSessionType(
        uint256 lensProfileId,
        SessionTypeData calldata data
    ) 
        external
        nonReentrant
        isOwenrOrDispatcher(lensProfileId)
        returns (uint256 sessionTypeId)
    {
        sessionTypeId = sessionTypes.length + 1;
        
        address sessionNFT = createSessionNFT(
            lensProfileId,
            sessionTypeId,
            data.title
        );

        SessionType memory sessionType = SessionType({
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
            sessionNFT: sessionNFT,
            lensProfileId: lensProfileId
        });
        require(_validateSessionType(sessionType), "invalid sessionType");

        sessionTypes.push(sessionType);
        sessionTypeOwner[sessionTypeId] = lensProfileId;
        sessionTypesOwnedByProfile[lensProfileId].push(sessionTypeId);
    }

    function createSessionNFT(
        uint256 lensProfileId,
        uint256 sessionTypeId,
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

    function getContentURI(uint256 sessionTypeId, uint256 sessionNFTId)
        external
        view
        override
        returns (string memory)
    {
        return sessionBySessionTypeByNFT[sessionTypeId][sessionNFTId].contentURI;
    }

    function onSessionNFTTransfer(
        uint256 sessionTypeId,
        uint256 followNFTId,
        address from,
        address to
    ) external {
        SessionType memory sessionType = sessionTypes[sessionTypeId - 1];
        require(msg.sender == sessionType.sessionNFT, "NOT_SESSION_NFT");
        require(sessionType.locked != true, "locked");
    }

    function archivedSessionType(
        uint256 sessionTypeId
    )
        external
        isOwenrOrDispatcherBySessionTypeId(sessionTypeId)
    {
        sessionTypes[sessionTypeId - 1].archived = true;
    }

    function getSessionType(uint256 sessionTypeId)
        public
        view
        returns (SessionType memory)
    {
        require(sessionTypeId <= sessionTypes.length, "!sessionTypeId");
        return sessionTypes[sessionTypeId - 1];
    }

    function getAvailabilityBySessionTypeId(
        uint256 sessionTypeId,
        uint256 startTime,
        uint256 endTime
    )
        public
        view
        returns (SessionAvailability[] memory)
    {
        uint256 _days = endTime / 86400 - startTime / 86400;
        SessionAvailability[] memory sessionAvailabilitys = new SessionAvailability[](_days);
        SessionType memory sessionType = getSessionType(sessionTypeId);
        for (uint256 index = 0; index < _days; index++) {
            sessionAvailabilitys[index] = getAvailabeSlotsByDate(
                startTime + 86400 * index,
                sessionType
            );
        }
        return sessionAvailabilitys;
    }

    function getSessionTypesByProfile(uint256 lensProfileId)
        external
        view
        returns (
            uint256[] memory sessionTypeIds,
            SessionType[] memory sessionTypesByProfile
        )
    {
        uint256[] memory sessionTypeIds = sessionTypesOwnedByProfile[
            lensProfileId
        ];
        SessionType[] memory sessionTypesByProfile = new SessionType[](
            sessionTypeIds.length
        );
        for (uint256 i; i < sessionTypeIds.length; ++i) {
            sessionTypesByProfile[i] = sessionTypes[sessionTypeIds[i] - 1];
        }
        return (sessionTypeIds, sessionTypesByProfile);
    }

    function getAvailablitysByProfile(uint256 lensProfileId)
        external
        view
        returns (
            uint256[] memory availabilityIds,
            Availability[] memory availabilitysByProfile
        )
    {
        uint256[] memory availabilityIds = availabilitysOwnedByProfile[
            lensProfileId
        ];
        Availability[] memory availabilitysByProfile = new Availability[](
            availabilityIds.length
        );
        for (uint256 i; i < availabilityIds.length; ++i) {
            availabilitysByProfile[i] = availabilitys[availabilityIds[i] - 1];
        }
        return (availabilityIds, availabilitysByProfile);
    }

    function updateSessionType(
        uint256 sessionTypeId,
        SessionType calldata sessionType
    )
        external
        isOwenrOrDispatcherBySessionTypeId(sessionTypeId)
    {
        require(_validateSessionType(sessionType), "invalid sessionType");
        sessionTypes[sessionTypeId - 1] = sessionType;
    }

    function book(
        uint256 timestamp,
        uint256 sessionTypeId
    ) external payable nonReentrant {
        require(timestamp > block.timestamp, "!inFeature");

        SessionType memory sessionType = getSessionType(sessionTypeId);
        require(
            sessionType.archived == false,
            "sessionType archived"
        );
        require(timestamp < block.timestamp + sessionType.openBookingDeltaDays * 86400, "too early");

        if (sessionType.validateFollow) {
            require(checkFollowValidity(sessionType.lensProfileId, msg.sender), "!needFollow");
        }
        uint256 date = (timestamp / 86400) * 86400;
        uint8 startSlot = uint8((timestamp - date) / SLOT_DURATION);

        uint256 availableSlots = sessionType.availabilityId > 0 ? availabilitys[
            sessionType.availabilityId - 1
        ].availableSlots[_getWeekday(date)] : type(uint256).max;

        // lock slots
        if (startSlot + sessionType.durationInSlot > 240) {
            // first day
            calendarByProfileByDate[sessionType.lensProfileId][date] = _lockSlots(
                calendarByProfileByDate[sessionType.lensProfileId][date],
                availableSlots,
                startSlot,
                240
            );
            // next day
            uint256 nextDate = date + 86400;
            uint256 nextDateAvailableSlots = sessionType.availabilityId > 0 ? availabilitys[sessionType.availabilityId - 1].availableSlots[_getWeekday(nextDate)] : type(uint256).max;
            calendarByProfileByDate[sessionType.lensProfileId][nextDate] = _lockSlots(
                calendarByProfileByDate[sessionType.lensProfileId][nextDate],
                nextDateAvailableSlots,
                0,
                startSlot + sessionType.durationInSlot - 240
            );
        } else {
            calendarByProfileByDate[sessionType.lensProfileId][date] = _lockSlots(
                calendarByProfileByDate[sessionType.lensProfileId][date],
                availableSlots,
                startSlot,
                startSlot + sessionType.durationInSlot
            );
        }
        
        _pay(sessionType);
        // mint
        uint256 sessionNFTId = ISessionNFT(sessionType.sessionNFT).mint(msg.sender);
        sessionBySessionTypeByNFT[sessionTypeId][sessionNFTId] = Session({
            sessionTypeId: sessionTypeId,
            title: sessionType.title,
            start: timestamp,
            end: timestamp + sessionType.durationInSlot * SLOT_DURATION,
            contentURI: string(
                abi.encodePacked(SESSION_URL, "/", sessionTypeId, "/", sessionNFTId)
            )
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

    function getAvailabeSlotsByDate(uint256 timestamp, SessionType memory sessionType) internal view returns (SessionAvailability memory) {
        uint256 date = (timestamp / 86400) * 86400;
        uint256 availableSlots = sessionType.availabilityId > 0 ? availabilitys[
            sessionType.availabilityId - 1
        ].availableSlots[_getWeekday(date)] : type(uint256).max;

        return SessionAvailability({
            date: date, 
            availableSlot: ~calendarByProfileByDate[sessionType.lensProfileId][date] & availableSlots
        });
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
                !_isBitSet(_calendar, index) &&
                _isBitSet(availabilityByProfileByDay, index)
            , "!availableSlot");
            _calendar = _calendar | (uint256(1) << index);
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
