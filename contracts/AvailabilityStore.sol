// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;
import "./Manager.sol";
import {Availability} from "./interface/ISessions.sol";

abstract contract AvailabilityStore is Manager {
    mapping(address => Availability[]) private availabilityByUser;

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
}
