// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";
import {FrozenFundsRecoverOp, RewardOp, RewarderHub} from "src/reward/RewarderHub.sol";

/// @title RewarderHubComplianceTest
/// @notice Tests for pending balance tracking and withdrawExcess
contract RewarderHubComplianceTest is RewarderHubBaseTest {
    /* -------------------------------------------------------------------------- */
    /*                            Pending Balance Tracking                         */
    /* -------------------------------------------------------------------------- */

    function test_pendingBalance_incrementsOnPushReward() public {
        assertEq(hub.getPendingBalance(address(token)), 0);

        _pushReward(user1, 100e18);

        assertEq(hub.getPendingBalance(address(token)), 100e18);
    }

    function test_pendingBalance_incrementsOnBatch() public {
        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = _createRewardOp(user1, 100e18, address(token), bank);
        ops[1] = _createRewardOp(user2, 50e18, address(token), bank);
        ops[2] = _createRewardOp(user1, 25e18, address(token2), bank);

        vm.prank(rewarder);
        hub.batch(ops);

        assertEq(hub.getPendingBalance(address(token)), 150e18);
        assertEq(hub.getPendingBalance(address(token2)), 25e18);
    }

    function test_pendingBalance_decrementsOnClaim() public {
        _pushReward(user1, 100e18);

        vm.prank(user1);
        hub.claim(address(token));

        assertEq(hub.getPendingBalance(address(token)), 0);
    }

    function test_pendingBalance_decrementsOnClaimBatch() public {
        _pushReward(user1, 100e18);

        vm.prank(rewarder);
        hub.pushReward(user1, 50e18, address(token2), bank, attestation);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        vm.prank(user1);
        hub.claimBatch(tokens);

        assertEq(hub.getPendingBalance(address(token)), 0);
        assertEq(hub.getPendingBalance(address(token2)), 0);
    }

    function test_pendingBalance_decrementsOnRecoverFrozenFunds() public {
        _pushReward(user1, 100e18);

        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.warp(block.timestamp + hub.FREEZE_DURATION() + 1);

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});

        vm.prank(compliance);
        hub.recoverFrozenFunds(ops, makeAddr("recipient"));

        assertEq(hub.getPendingBalance(address(token)), 0);
    }

    function test_pendingBalance_multipleUsersAccurate() public {
        _pushReward(user1, 100e18);
        _pushReward(user2, 200e18);

        assertEq(hub.getPendingBalance(address(token)), 300e18);

        vm.prank(user1);
        hub.claim(address(token));

        assertEq(hub.getPendingBalance(address(token)), 200e18);

        vm.prank(user2);
        hub.claim(address(token));

        assertEq(hub.getPendingBalance(address(token)), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                              withdrawExcess                                 */
    /* -------------------------------------------------------------------------- */

    function test_withdrawExcess_success() public {
        _pushReward(user1, 100e18);

        // Simulate excess tokens (someone sent extra tokens directly)
        token.mint(address(hub), 50e18);

        uint256 contractBalance = token.balanceOf(address(hub));
        assertEq(contractBalance, 150e18);
        assertEq(hub.getPendingBalance(address(token)), 100e18);

        address recipient = makeAddr("recipient");

        vm.expectEmit(true, true, true, true);
        emit RewarderHub.ExcessWithdrawn(address(token), 50e18, recipient);

        vm.prank(compliance);
        uint256 excess = hub.withdrawExcess(address(token), recipient);

        assertEq(excess, 50e18);
        assertEq(token.balanceOf(recipient), 50e18);
        assertEq(token.balanceOf(address(hub)), 100e18);
    }

    function test_withdrawExcess_noExcess() public {
        _pushReward(user1, 100e18);

        // Contract balance exactly matches pending
        assertEq(token.balanceOf(address(hub)), 100e18);
        assertEq(hub.getPendingBalance(address(token)), 100e18);

        vm.prank(compliance);
        vm.expectRevert(RewarderHub.NothingToWithdraw.selector);
        hub.withdrawExcess(address(token), makeAddr("recipient"));
    }

    function test_withdrawExcess_afterPartialClaim() public {
        _pushReward(user1, 100e18);
        _pushReward(user2, 100e18);

        // Add excess
        token.mint(address(hub), 50e18);

        // user1 claims
        vm.prank(user1);
        hub.claim(address(token));

        // Now: balance = 150, pending = 100, excess = 50
        assertEq(token.balanceOf(address(hub)), 150e18);
        assertEq(hub.getPendingBalance(address(token)), 100e18);

        address recipient = makeAddr("recipient");

        vm.prank(compliance);
        uint256 excess = hub.withdrawExcess(address(token), recipient);

        assertEq(excess, 50e18);
        assertEq(token.balanceOf(recipient), 50e18);
    }

    function test_withdrawExcess_revert_notCompliance() public {
        token.mint(address(hub), 100e18);

        vm.prank(user1);
        vm.expectRevert();
        hub.withdrawExcess(address(token), user1);
    }

    function test_withdrawExcess_revert_invalidRecipient() public {
        token.mint(address(hub), 100e18);

        vm.prank(compliance);
        vm.expectRevert(RewarderHub.InvalidAddress.selector);
        hub.withdrawExcess(address(token), address(0));
    }

    function test_withdrawExcess_unknownToken() public {
        // Token that was never used for rewards
        MockErc20 unknownToken = new MockErc20();
        unknownToken.mint(address(hub), 100e18);

        address recipient = makeAddr("recipient");

        vm.prank(compliance);
        uint256 excess = hub.withdrawExcess(address(unknownToken), recipient);

        assertEq(excess, 100e18);
        assertEq(unknownToken.balanceOf(recipient), 100e18);
    }

    function test_withdrawExcess_preservesPendingBalance() public {
        _pushReward(user1, 100e18);
        token.mint(address(hub), 50e18);

        vm.prank(compliance);
        hub.withdrawExcess(address(token), makeAddr("recipient"));

        // User can still claim their full amount
        vm.prank(user1);
        hub.claim(address(token));

        assertEq(token.balanceOf(user1), 100e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Fuzz Tests                                       */
    /* -------------------------------------------------------------------------- */

    function testFuzz_pendingBalance_accuracy(uint96 reward1, uint96 reward2) public {
        // Bound to bank balance (1_000_000e18 total)
        reward1 = uint96(bound(reward1, 1, 500_000e18));
        reward2 = uint96(bound(reward2, 1, 500_000e18));

        _pushReward(user1, reward1);
        _pushReward(user2, reward2);

        uint256 expectedPending = uint256(reward1) + uint256(reward2);
        assertEq(hub.getPendingBalance(address(token)), expectedPending);

        vm.prank(user1);
        hub.claim(address(token));

        assertEq(hub.getPendingBalance(address(token)), reward2);
    }

    function testFuzz_withdrawExcess_amount(uint96 pendingAmount, uint96 excessAmount) public {
        // Bound to reasonable amounts
        pendingAmount = uint96(bound(pendingAmount, 1, 1_000_000e18));
        excessAmount = uint96(bound(excessAmount, 1, 1_000_000e18));

        _pushReward(user1, pendingAmount);
        token.mint(address(hub), excessAmount);

        address recipient = makeAddr("recipient");

        vm.prank(compliance);
        uint256 withdrawn = hub.withdrawExcess(address(token), recipient);

        assertEq(withdrawn, excessAmount);
        assertEq(token.balanceOf(recipient), excessAmount);
        // Pending amount preserved
        assertEq(hub.getPendingBalance(address(token)), pendingAmount);
    }
}
