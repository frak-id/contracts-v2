// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";

/// @title RewarderHubViewTest
/// @notice Tests for view functions
contract RewarderHubViewTest is RewarderHubBaseTest {
    /* -------------------------------------------------------------------------- */
    /*                               getClaimable                                 */
    /* -------------------------------------------------------------------------- */

    function test_getClaimable_basic() public {
        _pushReward(user1, 100e18);

        assertEq(hub.getClaimable(user1, address(token)), 100e18);
    }

    function test_getClaimable_accumulates() public {
        _pushReward(user1, 100e18);
        _pushReward(user1, 50e18);

        assertEq(hub.getClaimable(user1, address(token)), 150e18);
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

    function test_getClaimable_multipleUsers() public {
        _pushReward(user1, 100e18);
        _pushReward(user2, 200e18);

        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getClaimable(user2, address(token)), 200e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Fuzz Tests                                    */
    /* -------------------------------------------------------------------------- */

    function testFuzz_getClaimable_accuracy(uint96 amount1, uint96 amount2) public {
        vm.assume(amount1 <= 500_000e18);
        vm.assume(amount2 <= 500_000e18);

        if (amount1 > 0) {
            _pushReward(user1, amount1);
        }

        if (amount2 > 0) {
            _pushReward(user1, amount2);
        }

        uint256 expected = uint256(amount1) + uint256(amount2);
        assertEq(hub.getClaimable(user1, address(token)), expected);
    }
}
