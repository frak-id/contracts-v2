// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {RESOLVER_ROLE, REWARDER_ROLE, UPGRADE_ROLE} from "src/constants/Roles.sol";
import {RecoverOp, ResolveOp, RewarderHub} from "src/reward/RewarderHub.sol";

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
    /*                              resolveUserIds                                 */
    /* -------------------------------------------------------------------------- */

    function test_resolveUserIds_success() public {
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
        hub.resolveUserIds(ops);

        // Verify resolutions
        assertEq(hub.getResolution(userId1), user1);
        assertEq(hub.getResolution(userId2), user2);

        // Verify eager resolution moved funds to claimable
        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getClaimable(user2, address(token)), 200e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);
        assertEq(hub.getLocked(userId2, address(token)), 0);
    }

    function test_resolveUserIds_singleOp() public {
        // Lock some rewards first
        _lockReward(userId1, 100e18);

        ResolveOp[] memory ops = new ResolveOp[](1);
        ops[0] = ResolveOp({userId: userId1, wallet: user1});

        vm.expectEmit(true, true, false, false);
        emit RewarderHub.UserIdResolved(userId1, user1);

        vm.prank(resolver);
        hub.resolveUserIds(ops);

        assertEq(hub.getResolution(userId1), user1);
        // Verify eager resolution moved funds to claimable
        assertEq(hub.getClaimable(user1, address(token)), 100e18);
        assertEq(hub.getLocked(userId1, address(token)), 0);
    }

    function test_resolveUserIds_multipleUserIdsToSameWallet() public {
        // Lock rewards for multiple userIds
        _lockReward(userId1, 100e18);
        _lockReward(userId2, 50e18);

        // Resolve both to the same wallet
        ResolveOp[] memory ops = new ResolveOp[](2);
        ops[0] = ResolveOp({userId: userId1, wallet: user1});
        ops[1] = ResolveOp({userId: userId2, wallet: user1});

        vm.prank(resolver);
        hub.resolveUserIds(ops);

        assertEq(hub.getResolution(userId1), user1);
        assertEq(hub.getResolution(userId2), user1);
        assertEq(hub.getClaimable(user1, address(token)), 150e18);
    }

    function test_resolveUserIds_emptyArray() public {
        ResolveOp[] memory ops = new ResolveOp[](0);

        vm.prank(resolver);
        hub.resolveUserIds(ops); // Should not revert
    }

    function test_resolveUserIds_revert_notResolver() public {
        ResolveOp[] memory ops = new ResolveOp[](1);
        ops[0] = ResolveOp({userId: userId1, wallet: user1});

        vm.prank(user1);
        vm.expectRevert();
        hub.resolveUserIds(ops);
    }

    function test_resolveUserIds_revert_invalidWallet() public {
        ResolveOp[] memory ops = new ResolveOp[](1);
        ops[0] = ResolveOp({userId: userId1, wallet: address(0)});

        vm.prank(resolver);
        vm.expectRevert(RewarderHub.InvalidAddress.selector);
        hub.resolveUserIds(ops);
    }

    function test_resolveUserIds_revert_alreadyResolved() public {
        _resolveUserId(userId1, user1);

        ResolveOp[] memory ops = new ResolveOp[](2);
        ops[0] = ResolveOp({userId: userId1, wallet: user2}); // Already resolved
        ops[1] = ResolveOp({userId: userId2, wallet: user2});

        vm.prank(resolver);
        vm.expectRevert(RewarderHub.AlreadyResolved.selector);
        hub.resolveUserIds(ops);
    }

    /* -------------------------------------------------------------------------- */
    /*                               recoverLocked                                */
    /* -------------------------------------------------------------------------- */

    function test_recoverLocked_success() public {
        // Lock rewards for multiple userIds with different tokens
        _lockReward(userId1, 100e18);
        vm.prank(rewarder);
        hub.lockReward(userId2, 200e18, address(token2), bank, attestation);

        uint256 ownerToken1Before = token.balanceOf(owner);
        uint256 ownerToken2Before = token2.balanceOf(owner);

        RecoverOp[] memory ops = new RecoverOp[](2);
        ops[0] = RecoverOp({userId: userId1, token: address(token)});
        ops[1] = RecoverOp({userId: userId2, token: address(token2)});

        vm.expectEmit(true, true, false, true);
        emit RewarderHub.LockedRecovered(userId1, address(token), 100e18, owner);
        vm.expectEmit(true, true, false, true);
        emit RewarderHub.LockedRecovered(userId2, address(token2), 200e18, owner);

        vm.prank(owner);
        hub.recoverLocked(ops);

        // Verify locked is cleared
        assertEq(hub.getLocked(userId1, address(token)), 0);
        assertEq(hub.getLocked(userId2, address(token2)), 0);

        // Verify owner received funds
        assertEq(token.balanceOf(owner), ownerToken1Before + 100e18);
        assertEq(token2.balanceOf(owner), ownerToken2Before + 200e18);
    }

    function test_recoverLocked_singleOp() public {
        _lockReward(userId1, 100e18);

        uint256 ownerBalanceBefore = token.balanceOf(owner);

        RecoverOp[] memory ops = new RecoverOp[](1);
        ops[0] = RecoverOp({userId: userId1, token: address(token)});

        vm.expectEmit(true, true, false, true);
        emit RewarderHub.LockedRecovered(userId1, address(token), 100e18, owner);

        vm.prank(owner);
        hub.recoverLocked(ops);

        assertEq(hub.getLocked(userId1, address(token)), 0);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + 100e18);
    }

    function test_recoverLocked_sameUserIdMultipleTokens() public {
        // Lock multiple tokens for same userId
        _lockReward(userId1, 100e18);
        vm.prank(rewarder);
        hub.lockReward(userId1, 50e18, address(token2), bank, attestation);

        RecoverOp[] memory ops = new RecoverOp[](2);
        ops[0] = RecoverOp({userId: userId1, token: address(token)});
        ops[1] = RecoverOp({userId: userId1, token: address(token2)});

        vm.prank(owner);
        hub.recoverLocked(ops);

        assertEq(hub.getLocked(userId1, address(token)), 0);
        assertEq(hub.getLocked(userId1, address(token2)), 0);
    }

    function test_recoverLocked_emptyArray() public {
        RecoverOp[] memory ops = new RecoverOp[](0);

        vm.prank(owner);
        hub.recoverLocked(ops); // Should not revert
    }

    function test_recoverLocked_revert_notOwner() public {
        _lockReward(userId1, 100e18);

        RecoverOp[] memory ops = new RecoverOp[](1);
        ops[0] = RecoverOp({userId: userId1, token: address(token)});

        vm.prank(rewarder);
        vm.expectRevert();
        hub.recoverLocked(ops);
    }

    function test_recoverLocked_revert_alreadyResolved() public {
        _lockReward(userId1, 100e18);
        _lockReward(userId2, 50e18);
        _resolveUserId(userId1, user1);

        RecoverOp[] memory ops = new RecoverOp[](2);
        ops[0] = RecoverOp({userId: userId1, token: address(token)}); // Already resolved
        ops[1] = RecoverOp({userId: userId2, token: address(token)});

        vm.prank(owner);
        vm.expectRevert(RewarderHub.CannotRecoverResolved.selector);
        hub.recoverLocked(ops);
    }

    function test_recoverLocked_revert_nothingToRecover() public {
        _lockReward(userId1, 100e18);

        RecoverOp[] memory ops = new RecoverOp[](2);
        ops[0] = RecoverOp({userId: userId1, token: address(token)});
        ops[1] = RecoverOp({userId: userId2, token: address(token)}); // Nothing locked

        vm.prank(owner);
        vm.expectRevert(RewarderHub.NothingToRecover.selector);
        hub.recoverLocked(ops);
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
