// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {Snapshots} from "./Snapshots.sol";
import {PropertiesAsserts} from "./utils/PropertiesAsserts.sol";

/// @notice Contains the functions that check the properties (invariants)
abstract contract Properties is PropertiesAsserts, Snapshots {

    // ―――――――――――――――――――― Global properties ―――――――――――――――――――――
    // These properties must always hold after any function call.
    // They MUST BE PUBLIC so that fuzzers can find and call them.

    /// @notice GL-01 (I-1) — Per-token conservation: pendingBalance[token] == Σ_wallet claimable[wallet][token].
    /// @dev SHOULD-HOLD. Every claimable write is matched 1:1 with a pendingBalance write in RewarderHub.
    ///      All reward credits are bounded to the actor set by the handlers, so the sum is enumerable.
    function property_pendingEqualsSumClaimable() public returns (bool) {
        for (uint256 i; i < tokens.length; i++) {
            address tkn = tokens[i];
            uint256 sum;
            for (uint256 a; a < actors.length; a++) {
                sum += hub.getClaimable(actors[a], tkn);
            }
            eq(hub.getPendingBalance(tkn), sum, "GL-01: pendingBalance must equal sum of claimable");
            if (hub.getPendingBalance(tkn) != sum) return false;
        }
        return true;
    }

    /// @notice GL-02 (I-2 / E-1) — Solvency: token.balanceOf(hub) >= pendingBalance[token].
    /// @dev SHOULD-HOLD for standard ERC20s (both reward tokens are standard). Funds are pulled in at
    ///      credit time, so the hub always custodies at least its tracked liabilities.
    function property_hubSolvent() public returns (bool) {
        for (uint256 i; i < tokens.length; i++) {
            address tkn = tokens[i];
            uint256 bal = tokenBalanceOf(tkn, address(hub));
            uint256 pending = hub.getPendingBalance(tkn);
            gte(bal, pending, "GL-02: hub balance must cover pending liabilities");
            if (bal < pending) return false;
        }
        return true;
    }

    // ――――――――――――――――――― Specific properties ――――――――――――――――――――
    // These properties must hold after specific function calls.
    // They MUST BE INTERNAL and called at the end of the relevant handlers.

    /// @notice SP-01 — After a successful single-token claim, the caller's claimable for that token is 0
    ///         and their token balance increased by exactly the claimed amount.
    /// @dev SHOULD-HOLD. `claim` zeroes claimable, decrements pendingBalance, and transfers `claimed` out.
    function _prop_claimSettles(address claimer, address tkn, uint256 balBefore, uint256 claimableBefore) internal {
        eq(hub.getClaimable(claimer, tkn), 0, "SP-01: claimable must be zero after claim");
        eq(
            tokenBalanceOf(tkn, claimer) - balBefore,
            claimableBefore,
            "SP-01: claimer balance must increase by claimed amount"
        );
    }
}
