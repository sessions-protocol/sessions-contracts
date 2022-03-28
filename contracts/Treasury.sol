pragma solidity 0.8.13;

contract Treasury {
    address public gov;
    uint16 internal constant BPS_MAX = 10000;
    mapping(address => bool) internal tokenWhitelisted;
    address payable internal treasury;
    uint16 internal treasuryFee;

    modifier onlyGov() {
        require(msg.sender == gov, "!gov");
        _;
    }
    function setTreasury(address payable newTreasury) external onlyGov {
        require(newTreasury != address(0));
        treasury = newTreasury;
    }

    function setTreasuryFee(uint16 newTreasuryFee) external onlyGov {
        require(newTreasuryFee < BPS_MAX / 2, "invalid treasury fee");
        treasuryFee = newTreasuryFee;
    }
    function whitelistCurrency(address token, bool toWhitelist)
        external
        onlyGov
    {
        require(token != address(0));
        tokenWhitelisted[token] = toWhitelist;
    }

    uint256[240] private __gap;
}
