// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";
import {RewarderHub} from "src/reward/RewarderHub.sol";

/// @title RewarderHubClaimTest
/// @notice Tests for claim and claimBatch functions
contract RewarderHubClaimTest is RewarderHubBaseTest {
    /* -------------------------------------------------------------------------- */
    /*                                   claim                                    */
    /* -------------------------------------------------------------------------- */

    function test_claim_success() public {
        _pushReward(user1, 100e18);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit RewarderHub.RewardClaimed(user1, address(token), 100e18);

        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, 100e18);
        assertEq(token.balanceOf(user1), balanceBefore + 100e18);
        assertEq(hub.getClaimable(user1, address(token)), 0);
    }

    function test_claim_multipleRewards() public {
        // Push multiple rewards
        _pushReward(user1, 100e18);
        _pushReward(user1, 50e18);

        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, 150e18);
        assertEq(token.balanceOf(user1), 150e18);
    }

    function test_claim_onlyClaimsRequestedToken() public {
        // Push rewards in both tokens
        _pushReward(user1, 100e18);

        vm.prank(rewarder);
        hub.pushReward(user1, 200e18, address(token2), bank, attestation);

        // Claim only token1
        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, 100e18);
        assertEq(hub.getClaimable(user1, address(token)), 0);
        assertEq(hub.getClaimable(user1, address(token2)), 200e18);
    }

    function test_claim_clearsClaimableAfterClaim() public {
        _pushReward(user1, 100e18);

        // First claim
        vm.prank(user1);
        hub.claim(address(token));

        // Second claim should fail (nothing left)
        vm.prank(user1);
        vm.expectRevert(RewarderHub.NothingToClaim.selector);
        hub.claim(address(token));
    }

    function test_claim_revert_nothingToClaim() public {
        vm.prank(user1);
        vm.expectRevert(RewarderHub.NothingToClaim.selector);
        hub.claim(address(token));
    }

    function test_claim_revert_nothingToClaim_wrongToken() public {
        _pushReward(user1, 100e18);

        vm.prank(user1);
        vm.expectRevert(RewarderHub.NothingToClaim.selector);
        hub.claim(address(token2));
    }

    /* -------------------------------------------------------------------------- */
    /*                                 claimBatch                                 */
    /* -------------------------------------------------------------------------- */

    function test_claimBatch_multipleTokens() public {
        // Push rewards in both tokens
        _pushReward(user1, 100e18);

        vm.prank(rewarder);
        hub.pushReward(user1, 200e18, address(token2), bank, attestation);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        vm.prank(user1);
        uint256[] memory claimed = hub.claimBatch(tokens);

        assertEq(claimed.length, 2);
        assertEq(claimed[0], 100e18);
        assertEq(claimed[1], 200e18);

        assertEq(token.balanceOf(user1), 100e18);
        assertEq(token2.balanceOf(user1), 200e18);
    }

    function test_claimBatch_partialClaims() public {
        // Only push token1
        _pushReward(user1, 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        vm.prank(user1);
        uint256[] memory claimed = hub.claimBatch(tokens);

        assertEq(claimed[0], 100e18);
        assertEq(claimed[1], 0); // Nothing to claim for token2
    }

    function test_claimBatch_emptyArray() public {
        address[] memory tokens = new address[](0);

        vm.prank(user1);
        uint256[] memory claimed = hub.claimBatch(tokens);

        assertEq(claimed.length, 0);
    }

    function test_claimBatch_emitsEvents() public {
        _pushReward(user1, 100e18);

        vm.prank(rewarder);
        hub.pushReward(user1, 200e18, address(token2), bank, attestation);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        vm.expectEmit(true, true, false, true);
        emit RewarderHub.RewardClaimed(user1, address(token), 100e18);

        vm.expectEmit(true, true, false, true);
        emit RewarderHub.RewardClaimed(user1, address(token2), 200e18);

        vm.prank(user1);
        hub.claimBatch(tokens);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Claim - Fuzz Tests                            */
    /* -------------------------------------------------------------------------- */

    function testFuzz_claim_amount(uint96 amount) public {
        vm.assume(amount > 0 && amount <= 1_000_000e18);

        _pushReward(user1, amount);

        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testFuzz_claim_multipleRewards(uint8 numRewards) public {
        vm.assume(numRewards > 0 && numRewards <= 10);

        uint256 totalExpected = 0;

        for (uint256 i = 0; i < numRewards; i++) {
            uint256 amount = (i + 1) * 10e18;
            _pushReward(user1, amount);
            totalExpected += amount;
        }

        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, totalExpected);
    }
}
