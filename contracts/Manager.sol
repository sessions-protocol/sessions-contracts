// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

abstract contract Manager {
    address public gov;
    mapping(address => bool) private managerWhitelist;
    modifier onlyManager() {
        require(managerWhitelist[msg.sender], "!whitelisted");
        _;
    }
    modifier onlyManagerOrSelf(address self) {
        require(
            managerWhitelist[msg.sender] || msg.sender == self,
            "!manager or self"
        );
        _;
    }
    modifier onlyGov() {
        require(msg.sender == gov, "!gov");
        _;
    }

    function whitelistManager(address addr, bool toWhitelist) public onlyGov {
        require(addr != address(0), "!addr");
        managerWhitelist[addr] = toWhitelist;
    }
}
