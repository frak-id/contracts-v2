// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {RESOLVER_ROLE, REWARDER_ROLE, UPGRADE_ROLE} from "src/constants/Roles.sol";
import {ResolveOp, RewarderHub} from "src/reward/RewarderHub.sol";

/// @title RewarderHubAdminTest
/// @notice Tests for admin functions: pushReward, lockReward, resolveUserId, recoverLocked
contract RewarderHubAdminTest is RewarderHubBaseTest {
    /* -------------------------------------------------------------------------- */
    /*                              Initialization                                */
    /* -------------------------------------------------------------------------- */

    function test_init_setsOwner() public view {
        assertEq(hub.owner(), owner);
    }

    function test_init_setsUpgradeRole() public view {
        assertTrue(hub.hasAnyRole(owner, UPGRADE_ROLE));
    }

    function test_init_revert_alreadyInitialized() public {
        vm.expectRevert();
        hub.init(user1);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 pushReward                                 */
    /* -------------------------------------------------------------------------- */

    function test_pushReward_success() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, true, true, true);
        emit RewarderHub.RewardPushed(user1, address(token), bank, amount, attestation);

        _pushReward(user1, amount);

        assertEq(hub.getClaimable(user1, address(token)), amount);
        assertEq(token.balanceOf(address(hub)), amount);
    }

    function test_pushReward_multipleToSameUser() public {
        _pushReward(user1, 100e18);
        _pushReward(user1, 50e18);

        assertEq(hub.getClaimable(user1, address(token)), 150e18);
    }

    function test_pushReward_revert_notRewarder() public {
        vm.prank(user1);
        vm.expectRevert();
        hub.pushReward(user1, 100e18, address(token), bank, attestation);
    }

    function test_pushReward_revert_invalidAddress() public {
        vm.prank(rewarder);
        vm.expectRevert(RewarderHub.InvalidAddress.selector);
        hub.pushReward(address(0), 100e18, address(token), bank, attestation);
    }

    function test_pushReward_revert_invalidAmount() public {
        vm.prank(rewarder);
        vm.expectRevert(RewarderHub.InvalidAmount.selector);
        hub.pushReward(user1, 0, address(token), bank, attestation);
    }

    function test_pushReward_revert_insufficientBalance() public {
        vm.prank(rewarder);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        hub.pushReward(user1, 10_000_000e18, address(token), bank, attestation);
    }

    function test_pushReward_revert_insufficientAllowance() public {
        // Remove allowance
        vm.prank(bank);
        token.approve(address(hub), 0);

        vm.prank(rewarder);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        hub.pushReward(user1, 100e18, address(token), bank, attestation);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 lockReward                                 */
    /* -------------------------------------------------------------------------- */

    function test_lockReward_success() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, true, true, true);
        emit RewarderHub.RewardLocked(userId1, address(token), bank, amount, attestation);

        _lockReward(userId1, amount);

        assertEq(hub.getLocked(userId1, address(token)), amount);
        assertEq(token.balanceOf(address(hub)), amount);
    }

    function test_lockReward_multipleToSameUserId() public {
        _lockReward(userId1, 100e18);
        _lockReward(userId1, 50e18);

        assertEq(hub.getLocked(userId1, address(token)), 150e18);
    }

    function test_lockReward_autoForward_whenResolved() public {
        // First resolve userId to wallet
        _resolveUserId(userId1, user1);

        // Lock should auto-forward to wallet
        vm.expectEmit(true, true, true, true);
        emit RewarderHub.RewardPushed(user1, address(token), bank, 100e18, attestation);

        _lockReward(userId1, 100e18);

        // Should be in claimable, not locked
        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);
    }

    function test_lockReward_revert_notRewarder() public {
        vm.prank(user1);
        vm.expectRevert();
        hub.lockReward(userId1, 100e18, address(token), bank, attestation);
    }

    function test_lockReward_revert_invalidUserId() public {
        vm.prank(rewarder);
        vm.expectRevert(RewarderHub.InvalidAddress.selector);
        hub.lockReward(bytes32(0), 100e18, address(token), bank, attestation);
    }

    function test_lockReward_revert_invalidAmount() public {
        vm.prank(rewarder);
        vm.expectRevert(RewarderHub.InvalidAmount.selector);
        hub.lockReward(userId1, 0, address(token), bank, attestation);
    }

    /* -------------------------------------------------------------------------- */
    /*                               resolveUserId                                */
    /* -------------------------------------------------------------------------- */

    function test_resolveUserId_success() public {
        // Lock some rewards first
        _lockReward(userId1, 100e18);

        vm.expectEmit(true, true, false, false);
        emit RewarderHub.UserIdResolved(userId1, user1);

        _resolveUserId(userId1, user1);

        assertEq(hub.getResolution(userId1), user1);
        // Verify eager resolution moved funds to claimable
        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);
    }

    function test_resolveUserId_multipleToSameWallet() public {
        // Lock rewards for both userIds
        _lockReward(userId1, 100e18);
        _lockReward(userId2, 50e18);

        _resolveUserId(userId1, user1);
        _resolveUserId(userId2, user1);

        assertEq(hub.getResolution(userId1), user1);
        assertEq(hub.getResolution(userId2), user1);
        // Verify both were moved to claimable
        assertEq(hub.getClaimable(user1, address(token)), 150e18);
    }

    function test_resolveUserId_revert_notResolver() public {
        vm.prank(user1);
        vm.expectRevert();
        hub.resolveUserId(userId1, user1);
    }

    function test_resolveUserId_revert_invalidWallet() public {
        vm.prank(resolver);
        vm.expectRevert(RewarderHub.InvalidAddress.selector);
        hub.resolveUserId(userId1, address(0));
    }

    function test_resolveUserId_revert_alreadyResolved() public {
        _resolveUserId(userId1, user1);

        vm.prank(resolver);
        vm.expectRevert(RewarderHub.AlreadyResolved.selector);
        hub.resolveUserId(userId1, user2);
    }

    /* -------------------------------------------------------------------------- */
    /*                               batchResolve                                 */
    /* -------------------------------------------------------------------------- */

    function test_batchResolve_success() public {
        // Lock rewards for multiple userIds
        _lockReward(userId1, 100e18);
        _lockReward(userId2, 200e18);

        ResolveOp[] memory ops = new ResolveOp[](2);
        ops[0] = ResolveOp({userId: userId1, wallet: user1});
        ops[1] = ResolveOp({userId: userId2, wallet: user2});

        vm.expectEmit(true, true, false, false);
        emit RewarderHub.UserIdResolved(userId1, user1);
        vm.expectEmit(true, true, false, false);
        emit RewarderHub.UserIdResolved(userId2, user2);

        vm.prank(resolver);
        hub.batchResolve(ops);

        // Verify resolutions
        assertEq(hub.getResolution(userId1), user1);
        assertEq(hub.getResolution(userId2), user2);

        // Verify eager resolution moved funds to claimable
        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getClaimable(user2, address(token)), 200e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);
        assertEq(hub.getLocked(userId2, address(token)), 0);
    }

    function test_batchResolve_multipleUserIdsToSameWallet() public {
        // Lock rewards for multiple userIds
        _lockReward(userId1, 100e18);
        _lockReward(userId2, 50e18);

        // Resolve both to the same wallet
        ResolveOp[] memory ops = new ResolveOp[](2);
        ops[0] = ResolveOp({userId: userId1, wallet: user1});
        ops[1] = ResolveOp({userId: userId2, wallet: user1});

        vm.prank(resolver);
        hub.batchResolve(ops);

        assertEq(hub.getResolution(userId1), user1);
        assertEq(hub.getResolution(userId2), user1);
        assertEq(hub.getClaimable(user1, address(token)), 150e18);
    }

    function test_batchResolve_emptyArray() public {
        ResolveOp[] memory ops = new ResolveOp[](0);

        vm.prank(resolver);
        hub.batchResolve(ops); // Should not revert
    }

    function test_batchResolve_revert_notResolver() public {
        ResolveOp[] memory ops = new ResolveOp[](1);
        ops[0] = ResolveOp({userId: userId1, wallet: user1});

        vm.prank(user1);
        vm.expectRevert();
        hub.batchResolve(ops);
    }

    function test_batchResolve_revert_invalidWallet() public {
        ResolveOp[] memory ops = new ResolveOp[](1);
        ops[0] = ResolveOp({userId: userId1, wallet: address(0)});

        vm.prank(resolver);
        vm.expectRevert(RewarderHub.InvalidAddress.selector);
        hub.batchResolve(ops);
    }

    function test_batchResolve_revert_alreadyResolved() public {
        _resolveUserId(userId1, user1);

        ResolveOp[] memory ops = new ResolveOp[](2);
        ops[0] = ResolveOp({userId: userId1, wallet: user2}); // Already resolved
        ops[1] = ResolveOp({userId: userId2, wallet: user2});

        vm.prank(resolver);
        vm.expectRevert(RewarderHub.AlreadyResolved.selector);
        hub.batchResolve(ops);
    }

    /* -------------------------------------------------------------------------- */
    /*                               recoverLocked                                */
    /* -------------------------------------------------------------------------- */

    function test_recoverLocked_success() public {
        _lockReward(userId1, 100e18);

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vm.expectEmit(true, true, false, true);
        emit RewarderHub.LockedRecovered(userId1, address(token), 100e18, owner);

        vm.prank(owner);
        hub.recoverLocked(userId1, address(token));

        assertEq(hub.getLocked(userId1, address(token)), 0);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + 100e18);
    }

    function test_recoverLocked_revert_notOwner() public {
        _lockReward(userId1, 100e18);

        vm.prank(rewarder);
        vm.expectRevert();
        hub.recoverLocked(userId1, address(token));
    }

    function test_recoverLocked_revert_alreadyResolved() public {
        _lockReward(userId1, 100e18);
        _resolveUserId(userId1, user1);

        vm.prank(owner);
        vm.expectRevert(RewarderHub.CannotRecoverResolved.selector);
        hub.recoverLocked(userId1, address(token));
    }

    function test_recoverLocked_revert_nothingToRecover() public {
        vm.prank(owner);
        vm.expectRevert(RewarderHub.NothingToRecover.selector);
        hub.recoverLocked(userId1, address(token));
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Upgrade                                   */
    /* -------------------------------------------------------------------------- */

    function test_upgrade_onlyUpgradeRole() public {
        RewarderHub newImpl = new RewarderHub();

        vm.prank(owner);
        hub.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgrade_revert_notUpgradeRole() public {
        RewarderHub newImpl = new RewarderHub();

        vm.prank(user1);
        vm.expectRevert();
        hub.upgradeToAndCall(address(newImpl), "");
    }
}
