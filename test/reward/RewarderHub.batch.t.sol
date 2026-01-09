// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";
import {RewarderHub, RewardOp} from "src/reward/RewarderHub.sol";

/// @title RewarderHubBatchTest
/// @notice Tests for batch operations with partial failures
contract RewarderHubBatchTest is RewarderHubBaseTest {
    /* -------------------------------------------------------------------------- */
    /*                              Batch - Success                               */
    /* -------------------------------------------------------------------------- */

    function test_batch_allPush_success() public {
        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);
        ops[1] = _createRewardOp(false, _addressToBytes32(user2), 200e18, address(token), bank);
        ops[2] = _createRewardOp(false, _addressToBytes32(user1), 50e18, address(token2), bank);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertEq(results.length, 3);
        assertTrue(results[0]);
        assertTrue(results[1]);
        assertTrue(results[2]);

        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getClaimable(user2, address(token)), 200e18);
        assertEq(hub.getClaimable(user1, address(token2)), 50e18);
    }

    function test_batch_allLock_success() public {
        RewardOp[] memory ops = new RewardOp[](2);
        ops[0] = _createRewardOp(true, userId1, 100e18, address(token), bank);
        ops[1] = _createRewardOp(true, userId2, 200e18, address(token), bank);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertTrue(results[0]);
        assertTrue(results[1]);

        assertEq(hub.getLocked(userId1, address(token)), 100e18);
        assertEq(hub.getLocked(userId2, address(token)), 200e18);
    }

    function test_batch_mixedPushAndLock_success() public {
        RewardOp[] memory ops = new RewardOp[](4);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);
        ops[1] = _createRewardOp(true, userId1, 150e18, address(token), bank);
        ops[2] = _createRewardOp(false, _addressToBytes32(user2), 200e18, address(token2), bank);
        ops[3] = _createRewardOp(true, userId2, 75e18, address(token2), bank);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertTrue(results[0]);
        assertTrue(results[1]);
        assertTrue(results[2]);
        assertTrue(results[3]);

        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getLocked(userId1, address(token)), 150e18);
        assertEq(hub.getClaimable(user2, address(token2)), 200e18);
        assertEq(hub.getLocked(userId2, address(token2)), 75e18);
    }

    function test_batch_lockAutoForward_whenResolved() public {
        // Resolve userId1 to user1
        _resolveUserId(userId1, user1);

        RewardOp[] memory ops = new RewardOp[](2);
        ops[0] = _createRewardOp(true, userId1, 100e18, address(token), bank); // Should auto-forward
        ops[1] = _createRewardOp(true, userId2, 200e18, address(token), bank); // Should lock

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertTrue(results[0]);
        assertTrue(results[1]);

        // userId1 was resolved, so goes to claimable
        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);

        // userId2 not resolved, stays locked
        assertEq(hub.getLocked(userId2, address(token)), 200e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Batch - Partial Failures                         */
    /* -------------------------------------------------------------------------- */

    function test_batch_partialFailure_insufficientBalance() public {
        // First op uses most of the balance
        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 900_000e18, address(token), bank);
        ops[1] = _createRewardOp(false, _addressToBytes32(user2), 200_000e18, address(token), bank); // Should fail
        ops[2] = _createRewardOp(false, _addressToBytes32(user1), 50_000e18, address(token), bank);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertTrue(results[0]);
        assertFalse(results[1]); // Failed due to insufficient balance
        assertTrue(results[2]);

        assertEq(hub.getClaimable(user1, address(token)), 950_000e18);
        assertEq(hub.getClaimable(user2, address(token)), 0);
    }

    function test_batch_partialFailure_insufficientAllowance() public {
        // Set limited allowance
        vm.prank(bank);
        token.approve(address(hub), 150e18);

        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);
        ops[1] = _createRewardOp(false, _addressToBytes32(user2), 100e18, address(token), bank); // Should fail
        ops[2] = _createRewardOp(false, _addressToBytes32(user1), 50e18, address(token), bank);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertTrue(results[0]);
        assertFalse(results[1]); // Failed due to insufficient allowance
        assertTrue(results[2]);
    }

    function test_batch_partialFailure_badToken() public {
        address badToken = makeAddr("badToken");

        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);
        ops[1] = _createRewardOp(false, _addressToBytes32(user2), 100e18, badToken, bank); // Should fail
        ops[2] = _createRewardOp(false, _addressToBytes32(user1), 50e18, address(token), bank);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertTrue(results[0]);
        assertFalse(results[1]); // Failed due to bad token
        assertTrue(results[2]);
    }

    function test_batch_partialFailure_badBank() public {
        address badBank = makeAddr("badBank");

        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);
        ops[1] = _createRewardOp(false, _addressToBytes32(user2), 100e18, address(token), badBank); // Should fail
        ops[2] = _createRewardOp(false, _addressToBytes32(user1), 50e18, address(token), bank);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertTrue(results[0]);
        assertFalse(results[1]); // Failed due to bad bank (no balance/allowance)
        assertTrue(results[2]);
    }

    function test_batch_allFail() public {
        address badBank = makeAddr("badBank");

        RewardOp[] memory ops = new RewardOp[](2);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), badBank);
        ops[1] = _createRewardOp(false, _addressToBytes32(user2), 100e18, address(token), badBank);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertFalse(results[0]);
        assertFalse(results[1]);

        assertEq(hub.getClaimable(user1, address(token)), 0);
        assertEq(hub.getClaimable(user2, address(token)), 0);
    }

    function test_batch_emptyArray() public {
        RewardOp[] memory ops = new RewardOp[](0);

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        assertEq(results.length, 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Batch - Access Control                        */
    /* -------------------------------------------------------------------------- */

    function test_batch_revert_notRewarder() public {
        RewardOp[] memory ops = new RewardOp[](1);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);

        vm.prank(user1);
        vm.expectRevert();
        hub.batch(ops);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Batch - Events                                */
    /* -------------------------------------------------------------------------- */

    function test_batch_emitsEvents() public {
        RewardOp[] memory ops = new RewardOp[](2);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);
        ops[1] = _createRewardOp(true, userId1, 200e18, address(token), bank);

        vm.expectEmit(true, true, true, true);
        emit RewarderHub.RewardPushed(user1, address(token), bank, 100e18, attestation);

        vm.expectEmit(true, true, true, true);
        emit RewarderHub.RewardLocked(userId1, address(token), bank, 200e18, attestation);

        vm.prank(rewarder);
        hub.batch(ops);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Batch - Fuzz Tests                            */
    /* -------------------------------------------------------------------------- */

    function testFuzz_batch_multipleOps(uint8 numOps, uint96 baseAmount) public {
        vm.assume(numOps > 0 && numOps <= 20);
        vm.assume(baseAmount > 0 && baseAmount <= 10_000e18);

        RewardOp[] memory ops = new RewardOp[](numOps);
        uint256 totalExpected = 0;

        for (uint256 i = 0; i < numOps; i++) {
            uint256 amount = uint256(baseAmount) + i * 1e18;
            ops[i] = _createRewardOp(false, _addressToBytes32(user1), amount, address(token), bank);
            totalExpected += amount;
        }

        // Ensure bank has enough
        if (totalExpected > token.balanceOf(bank)) {
            token.mint(bank, totalExpected);
        }

        vm.prank(rewarder);
        bool[] memory results = hub.batch(ops);

        for (uint256 i = 0; i < numOps; i++) {
            assertTrue(results[i]);
        }

        assertEq(hub.getClaimable(user1, address(token)), totalExpected);
    }
}
