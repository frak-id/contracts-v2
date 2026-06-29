// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../Base.sol";
import {Properties} from "../Properties.sol";

/// @notice Handles the interaction with mUSDToken
/// @dev `admin` holds MINTER_ROLE so mint uses `asAdmin`; ERC20 moves are user actions (`asActor`).
abstract contract mUSDTokenHandler is Properties {
    // ――――――――――――――――――――――――― Clamped ――――――――――――――――――――――――――

    /// @notice Mint mUSD to an actor (bounded to keep balances in a sane range).
    function mUSDToken_mint_clamped(address _to, uint256 _amount) public {
        _to = toActor(_to);
        _amount = clampBetween(_amount, 1, 1_000_000e18);
        mUSDToken_mint(_to, _amount);
    }

    /// @notice Transfer mUSD between actors, bounded by the sender's balance.
    function mUSDToken_transfer_clamped(address to, uint256 amount) public {
        uint256 bal = musd.balanceOf(actor);
        if (bal == 0) return;
        to = toActor(to);
        amount = clampBetween(amount, 1, bal);
        mUSDToken_transfer(to, amount);
    }

    /// @notice Approve another actor to spend the current actor's mUSD.
    function mUSDToken_approve_clamped(address spender, uint256 amount) public {
        mUSDToken_approve(toActor(spender), amount);
    }

    /// @notice Pull mUSD from one actor to another via a previously-set allowance.
    function mUSDToken_transferFrom_clamped(address from, address to, uint256 amount) public {
        from = toActor(from);
        to = toActor(to);
        uint256 bal = musd.balanceOf(from);
        uint256 allowed = musd.allowance(from, actor);
        uint256 max = bal < allowed ? bal : allowed;
        if (max == 0) return;
        amount = clampBetween(amount, 1, max);
        mUSDToken_transferFrom(from, to, amount);
    }

    // ―――――――――――――――――――――――― Unclamped ―――――――――――――――――――――――――

    function mUSDToken_mint(address _to, uint256 _amount) public asAdmin {
        musd.mint(_to, _amount);
    }

    function mUSDToken_transfer(address to, uint256 amount) public asActor {
        musd.transfer(to, amount);
    }

    function mUSDToken_approve(address spender, uint256 amount) public asActor {
        musd.approve(spender, amount);
    }

    function mUSDToken_transferFrom(address from, address to, uint256 amount) public asActor {
        musd.transferFrom(from, to, amount);
    }
}
