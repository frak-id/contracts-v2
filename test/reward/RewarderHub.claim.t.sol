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

    function test_claim_directClaimable() public {
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

    function test_claim_fromResolvedUserId() public {
        // Lock reward for userId
        _lockReward(userId1, 100e18);

        // Resolve userId to user1
        _resolveUserId(userId1, user1);

        // User can claim the locked reward
        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, 100e18);
        assertEq(token.balanceOf(user1), 100e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);
    }

    function test_claim_combinedDirectAndResolved() public {
        // Push direct reward
        _pushReward(user1, 100e18);

        // Lock reward for userId
        _lockReward(userId1, 50e18);

        // Resolve userId to user1
        _resolveUserId(userId1, user1);

        // User can claim both
        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, 150e18);
        assertEq(token.balanceOf(user1), 150e18);
    }

    function test_claim_multipleResolvedUserIds() public {
        // Lock rewards for multiple userIds
        _lockReward(userId1, 100e18);
        _lockReward(userId2, 200e18);

        // Resolve both to same user
        _resolveUserId(userId1, user1);
        _resolveUserId(userId2, user1);

        // User can claim all
        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, 300e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);
        assertEq(hub.getLocked(userId2, address(token)), 0);
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

    function test_claim_clearsLockedAfterClaim() public {
        _lockReward(userId1, 100e18);
        _resolveUserId(userId1, user1);

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

    function test_claimBatch_withResolvedUserIds() public {
        // Lock rewards
        _lockReward(userId1, 100e18);

        vm.prank(rewarder);
        hub.lockReward(userId1, 200e18, address(token2), bank, attestation);

        // Resolve
        _resolveUserId(userId1, user1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        vm.prank(user1);
        uint256[] memory claimed = hub.claimBatch(tokens);

        assertEq(claimed[0], 100e18);
        assertEq(claimed[1], 200e18);
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

    function test_claimBatch_combinedDirectAndResolved() public {
        // Direct push
        _pushReward(user1, 100e18);

        // Lock for userId
        _lockReward(userId1, 50e18);

        // Another lock for userId in token2
        vm.prank(rewarder);
        hub.lockReward(userId1, 75e18, address(token2), bank, attestation);

        // Resolve
        _resolveUserId(userId1, user1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        vm.prank(user1);
        uint256[] memory claimed = hub.claimBatch(tokens);

        assertEq(claimed[0], 150e18); // 100 direct + 50 locked
        assertEq(claimed[1], 75e18); // 75 locked
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

    function testFuzz_claim_multipleUserIds(uint8 numUserIds) public {
        vm.assume(numUserIds > 0 && numUserIds <= 10);

        uint256 totalExpected = 0;

        for (uint256 i = 0; i < numUserIds; i++) {
            bytes32 userId = keccak256(abi.encodePacked("userId", i));
            uint256 amount = (i + 1) * 10e18;

            _lockReward(userId, amount);
            _resolveUserId(userId, user1);

            totalExpected += amount;
        }

        vm.prank(user1);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, totalExpected);
    }
}
