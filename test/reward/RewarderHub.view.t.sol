// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";

/// @title RewarderHubViewTest
/// @notice Tests for view functions
contract RewarderHubViewTest is RewarderHubBaseTest {
    /* -------------------------------------------------------------------------- */
    /*                               getClaimable                                 */
    /* -------------------------------------------------------------------------- */

    function test_getClaimable_directOnly() public {
        _pushReward(user1, 100e18);

        assertEq(hub.getClaimable(user1, address(token)), 100e18);
    }

    function test_getClaimable_resolvedOnly() public {
        _lockReward(userId1, 100e18);
        _resolveUserId(userId1, user1);

        assertEq(hub.getClaimable(user1, address(token)), 100e18);
    }

    function test_getClaimable_combined() public {
        // Direct
        _pushReward(user1, 100e18);

        // Locked then resolved
        _lockReward(userId1, 50e18);
        _resolveUserId(userId1, user1);

        assertEq(hub.getClaimable(user1, address(token)), 150e18);
    }

    function test_getClaimable_multipleResolvedUserIds() public {
        _lockReward(userId1, 100e18);
        _lockReward(userId2, 200e18);

        _resolveUserId(userId1, user1);
        _resolveUserId(userId2, user1);

        assertEq(hub.getClaimable(user1, address(token)), 300e18);
    }

    function test_getClaimable_zeroWhenNone() public view {
        assertEq(hub.getClaimable(user1, address(token)), 0);
    }

    function test_getClaimable_zeroAfterClaim() public {
        _pushReward(user1, 100e18);

        vm.prank(user1);
        hub.claim(address(token));

        assertEq(hub.getClaimable(user1, address(token)), 0);
    }

    function test_getClaimable_multipleTokens() public {
        _pushReward(user1, 100e18);

        vm.prank(rewarder);
        hub.pushReward(user1, 200e18, address(token2), bank, attestation);

        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getClaimable(user1, address(token2)), 200e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 getLocked                                  */
    /* -------------------------------------------------------------------------- */

    function test_getLocked_basic() public {
        _lockReward(userId1, 100e18);

        assertEq(hub.getLocked(userId1, address(token)), 100e18);
    }

    function test_getLocked_accumulates() public {
        _lockReward(userId1, 100e18);
        _lockReward(userId1, 50e18);

        assertEq(hub.getLocked(userId1, address(token)), 150e18);
    }

    function test_getLocked_zeroWhenNone() public view {
        assertEq(hub.getLocked(userId1, address(token)), 0);
    }

    function test_getLocked_zeroAfterResolve() public {
        _lockReward(userId1, 100e18);
        _resolveUserId(userId1, user1);

        // Eager resolution moves funds to claimable
        assertEq(hub.getLocked(userId1, address(token)), 0);
        assertEq(hub.getClaimable(user1, address(token)), 100e18);
    }

    function test_getLocked_multipleTokens() public {
        _lockReward(userId1, 100e18);

        vm.prank(rewarder);
        hub.lockReward(userId1, 200e18, address(token2), bank, attestation);

        assertEq(hub.getLocked(userId1, address(token)), 100e18);
        assertEq(hub.getLocked(userId1, address(token2)), 200e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                               getResolution                                */
    /* -------------------------------------------------------------------------- */

    function test_getResolution_resolved() public {
        _resolveUserId(userId1, user1);

        assertEq(hub.getResolution(userId1), user1);
    }

    function test_getResolution_notResolved() public view {
        assertEq(hub.getResolution(userId1), address(0));
    }

    function test_getResolution_multipleUserIds() public {
        _resolveUserId(userId1, user1);
        _resolveUserId(userId2, user2);

        assertEq(hub.getResolution(userId1), user1);
        assertEq(hub.getResolution(userId2), user2);
    }

    /* -------------------------------------------------------------------------- */
    /*                              getLockedTokens                               */
    /* -------------------------------------------------------------------------- */

    function test_getLockedTokens_single() public {
        _lockReward(userId1, 100e18);

        address[] memory tokens = hub.getLockedTokens(userId1);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(token));
    }

    function test_getLockedTokens_multiple() public {
        _lockReward(userId1, 100e18);

        vm.prank(rewarder);
        hub.lockReward(userId1, 200e18, address(token2), bank, attestation);

        address[] memory tokens = hub.getLockedTokens(userId1);
        assertEq(tokens.length, 2);
    }

    function test_getLockedTokens_empty() public view {
        address[] memory tokens = hub.getLockedTokens(userId1);
        assertEq(tokens.length, 0);
    }

    function test_getLockedTokens_emptyAfterResolve() public {
        _lockReward(userId1, 100e18);
        _resolveUserId(userId1, user1);

        // Eager resolution clears the token set
        address[] memory tokens = hub.getLockedTokens(userId1);
        assertEq(tokens.length, 0);
    }

    function test_getLockedTokens_noDuplicates() public {
        // Lock same token twice
        _lockReward(userId1, 100e18);
        _lockReward(userId1, 50e18);

        address[] memory tokens = hub.getLockedTokens(userId1);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(token));
    }

    /* -------------------------------------------------------------------------- */
    /*                              Fuzz Tests                                    */
    /* -------------------------------------------------------------------------- */

    function testFuzz_getClaimable_accuracy(uint96 directAmount, uint96 lockedAmount) public {
        vm.assume(directAmount <= 500_000e18);
        vm.assume(lockedAmount <= 500_000e18);

        if (directAmount > 0) {
            _pushReward(user1, directAmount);
        }

        if (lockedAmount > 0) {
            _lockReward(userId1, lockedAmount);
            _resolveUserId(userId1, user1);
        }

        uint256 expected = uint256(directAmount) + uint256(lockedAmount);
        assertEq(hub.getClaimable(user1, address(token)), expected);
    }

    function testFuzz_getLocked_accuracy(uint96 amount1, uint96 amount2) public {
        vm.assume(amount1 <= 500_000e18);
        vm.assume(amount2 <= 500_000e18);

        if (amount1 > 0) {
            _lockReward(userId1, amount1);
        }

        if (amount2 > 0) {
            _lockReward(userId1, amount2);
        }

        uint256 expected = uint256(amount1) + uint256(amount2);
        assertEq(hub.getLocked(userId1, address(token)), expected);
    }
}
