// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;
import "./Manager.sol";
import {SessionType} from "./interface/ISessions.sol";

abstract contract SessionTypeStore is Manager {
    // constant MAX_BPS= 10000

    mapping(address => SessionType[]) private sessionTypeByUser;

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
        // TODO: validate input data
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
}
