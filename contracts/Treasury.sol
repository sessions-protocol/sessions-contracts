pragma solidity 0.8.10;
import "./Manager.sol";

contract Treasury is Manager {
    uint16 internal constant BPS_MAX = 10000;
    mapping(address => bool) internal tokenWhitelisted;
    address internal treasury;
    uint16 internal treasuryFee;

    function setTreasury(address newTreasury) external onlyGov {
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
}
