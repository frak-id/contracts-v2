// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";
import {RewardOp, RewarderHub} from "src/reward/RewarderHub.sol";

/// @title RewarderHubBatchTest
/// @notice Tests for batch operations
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
        hub.batch(ops);

        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getClaimable(user2, address(token)), 200e18);
        assertEq(hub.getClaimable(user1, address(token2)), 50e18);
    }

    function test_batch_allLock_success() public {
        RewardOp[] memory ops = new RewardOp[](2);
        ops[0] = _createRewardOp(true, userId1, 100e18, address(token), bank);
        ops[1] = _createRewardOp(true, userId2, 200e18, address(token), bank);

        vm.prank(rewarder);
        hub.batch(ops);

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
        hub.batch(ops);

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
        hub.batch(ops);

        // userId1 was resolved, so goes to claimable
        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);

        // userId2 not resolved, stays locked
        assertEq(hub.getLocked(userId2, address(token)), 200e18);
    }

    function test_batch_emptyArray() public {
        RewardOp[] memory ops = new RewardOp[](0);

        vm.prank(rewarder);
        hub.batch(ops); // Should not revert
    }

    /* -------------------------------------------------------------------------- */
    /*                              Batch - Reverts                               */
    /* -------------------------------------------------------------------------- */

    function test_batch_revert_notRewarder() public {
        RewardOp[] memory ops = new RewardOp[](1);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);

        vm.prank(user1);
        vm.expectRevert();
        hub.batch(ops);
    }

    function test_batch_revert_insufficientBalance() public {
        RewardOp[] memory ops = new RewardOp[](1);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 2_000_000e18, address(token), bank);

        vm.prank(rewarder);
        vm.expectRevert();
        hub.batch(ops);
    }

    function test_batch_revert_insufficientAllowance() public {
        vm.prank(bank);
        token.approve(address(hub), 50e18);

        RewardOp[] memory ops = new RewardOp[](1);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), bank);

        vm.prank(rewarder);
        vm.expectRevert();
        hub.batch(ops);
    }

    function test_batch_revert_badBank() public {
        address badBank = makeAddr("badBank");

        RewardOp[] memory ops = new RewardOp[](1);
        ops[0] = _createRewardOp(false, _addressToBytes32(user1), 100e18, address(token), badBank);

        vm.prank(rewarder);
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
        hub.batch(ops);

        assertEq(hub.getClaimable(user1, address(token)), totalExpected);
    }

    /* -------------------------------------------------------------------------- */
    /*                        Batch - Realistic Benchmarks                        */
    /* -------------------------------------------------------------------------- */

    /// @notice Simulate real-world batch: 5 campaigns, 2 tokens each, ~100 ops
    /// Ops are sorted by (bank, token) as required
    function test_batch_benchmark_100ops() public {
        // Setup 5 banks (campaigns)
        address[] memory banks = new address[](5);
        for (uint256 i; i < 5; i++) {
            banks[i] = makeAddr(string(abi.encodePacked("bank", i)));
            token.mint(banks[i], 100_000e18);
            token2.mint(banks[i], 100_000e18);
            vm.startPrank(banks[i]);
            token.approve(address(hub), type(uint256).max);
            token2.approve(address(hub), type(uint256).max);
            vm.stopPrank();
        }

        // Create 100 ops sorted by (bank, token)
        // 5 banks * 2 tokens * 10 ops each = 100 ops
        RewardOp[] memory ops = new RewardOp[](100);
        uint256 idx;

        for (uint256 b; b < 5; b++) {
            // 10 ops for token
            for (uint256 i; i < 10; i++) {
                address recipient = i % 2 == 0 ? user1 : user2;
                bool isLock = i % 3 == 0;
                bytes32 target = isLock ? keccak256(abi.encodePacked("user", b, i)) : _addressToBytes32(recipient);
                ops[idx++] = _createRewardOp(isLock, target, 100e18, address(token), banks[b]);
            }
            // 10 ops for token2
            for (uint256 i; i < 10; i++) {
                address recipient = i % 2 == 0 ? user1 : user2;
                bool isLock = i % 3 == 0;
                bytes32 target = isLock ? keccak256(abi.encodePacked("user", b, i)) : _addressToBytes32(recipient);
                ops[idx++] = _createRewardOp(isLock, target, 50e18, address(token2), banks[b]);
            }
        }

        vm.prank(rewarder);
        hub.batch(ops);
    }

    /// @notice Simulate larger batch: 200 ops
    function test_batch_benchmark_200ops() public {
        // Setup 5 banks (campaigns)
        address[] memory banks = new address[](5);
        for (uint256 i; i < 5; i++) {
            banks[i] = makeAddr(string(abi.encodePacked("bank", i)));
            token.mint(banks[i], 500_000e18);
            token2.mint(banks[i], 500_000e18);
            vm.startPrank(banks[i]);
            token.approve(address(hub), type(uint256).max);
            token2.approve(address(hub), type(uint256).max);
            vm.stopPrank();
        }

        // Create 200 ops sorted by (bank, token)
        // 5 banks * 2 tokens * 20 ops each = 200 ops
        RewardOp[] memory ops = new RewardOp[](200);
        uint256 idx;

        for (uint256 b; b < 5; b++) {
            // 20 ops for token
            for (uint256 i; i < 20; i++) {
                address recipient = i % 2 == 0 ? user1 : user2;
                bool isLock = i % 3 == 0;
                bytes32 target = isLock ? keccak256(abi.encodePacked("user", b, i)) : _addressToBytes32(recipient);
                ops[idx++] = _createRewardOp(isLock, target, 100e18, address(token), banks[b]);
            }
            // 20 ops for token2
            for (uint256 i; i < 20; i++) {
                address recipient = i % 2 == 0 ? user1 : user2;
                bool isLock = i % 3 == 0;
                bytes32 target = isLock ? keccak256(abi.encodePacked("user", b, i)) : _addressToBytes32(recipient);
                ops[idx++] = _createRewardOp(isLock, target, 50e18, address(token2), banks[b]);
            }
        }

        vm.prank(rewarder);
        hub.batch(ops);
    }
}
