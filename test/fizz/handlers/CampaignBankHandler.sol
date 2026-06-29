// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../Base.sol";
import {Properties} from "../Properties.sol";

/// @notice Handles the interaction with CampaignBank
/// @dev The bank is owned by `admin` (the merchant), so all management actions use `asAdmin`.
abstract contract CampaignBankHandler is Properties {
    // ――――――――――――――――――――――――― Clamped ――――――――――――――――――――――――――

    /// @notice Deposit a registered reward token into the bank, bounded by the merchant's balance.
    function campaignBank_deposit_clamped(uint256 tokenSeed, uint256 _amount) public {
        address _token = toToken(tokenSeed);
        uint256 bal = tokenBalanceOf(_token, admin);
        if (bal == 0) return;
        _amount = clampBetween(_amount, 1, bal);
        campaignBank_deposit(_token, _amount);
    }

    /// @notice Withdraw a registered token from the bank (only succeeds while bank is closed).
    function campaignBank_withdraw_clamped(uint256 tokenSeed, uint256 _amount, address _to) public {
        address _token = toToken(tokenSeed);
        uint256 bal = tokenBalanceOf(_token, address(bank));
        if (bal == 0) return;
        _amount = clampBetween(_amount, 1, bal);
        _to = toActor(_to);
        campaignBank_withdraw(_token, _amount, _to);
    }

    /// @notice Arm/adjust the hub's pull allowance for a registered token (only while bank is open).
    function campaignBank_updateAllowance_clamped(uint256 tokenSeed, uint256 _amount) public {
        address _token = toToken(tokenSeed);
        campaignBank_updateAllowance(_token, _amount);
    }

    /// @notice Full-balance withdraw stress variant.
    function campaignBank_fullWithdraw(uint256 tokenSeed, address _to) public {
        address _token = toToken(tokenSeed);
        uint256 bal = tokenBalanceOf(_token, address(bank));
        if (bal == 0) return;
        campaignBank_withdraw(_token, bal, toActor(_to));
    }

    /// @notice Dispatcher for lower-frequency bank management actions.
    function campaignBank_secondary(uint8 selector, uint256 tokenSeed, uint256 _amount) public {
        selector = uint8(selector % 4);
        address _token = toToken(tokenSeed);
        if (selector == 0) {
            address[] memory ts = new address[](1);
            uint256[] memory amts = new uint256[](1);
            ts[0] = _token;
            amts[0] = _amount;
            _campaignBank_updateAllowances(ts, amts);
        } else if (selector == 1) {
            _campaignBank_revokeAllowance(_token);
        } else if (selector == 2) {
            address[] memory ts = new address[](1);
            ts[0] = _token;
            _campaignBank_revokeAllowances(ts);
        } else {
            _campaignBank_setOpen(_amount % 2 == 0);
        }
    }

    // ―――――――――――――――――――――――― Unclamped ―――――――――――――――――――――――――

    function campaignBank_deposit(address _token, uint256 _amount) public asAdmin {
        bank.deposit(_token, _amount);
    }

    function campaignBank_withdraw(address _token, uint256 _amount, address _to) public asAdmin {
        bank.withdraw(_token, _amount, _to);
    }

    function campaignBank_updateAllowance(address _token, uint256 _amount) public asAdmin {
        bank.updateAllowance(_token, _amount);
    }

    function _campaignBank_updateAllowances(address[] memory _tokens, uint256[] memory _amounts) internal asAdmin {
        bank.updateAllowances(_tokens, _amounts);
    }

    function _campaignBank_revokeAllowance(address _token) internal asAdmin {
        bank.revokeAllowance(_token);
    }

    function _campaignBank_revokeAllowances(address[] memory _tokens) internal asAdmin {
        bank.revokeAllowances(_tokens);
    }

    function _campaignBank_setOpen(bool _isOpen) internal asAdmin {
        bank.setOpen(_isOpen);
    }
}
