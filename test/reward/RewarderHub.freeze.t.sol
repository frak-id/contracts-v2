// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";
import {FrozenFundsRecoverOp, RewarderHub} from "src/reward/RewarderHub.sol";

/// @title RewarderHubFreezeTest
/// @notice Tests for freeze functionality: freezeUser, unfreezeUser, recoverFrozenFunds
contract RewarderHubFreezeTest is RewarderHubBaseTest {
    /* -------------------------------------------------------------------------- */
    /*                                 freezeUser                                  */
    /* -------------------------------------------------------------------------- */

    function test_freezeUser_success() public {
        vm.expectEmit(true, true, true, true);
        emit RewarderHub.UserFrozen(user1, block.timestamp);

        vm.prank(compliance);
        hub.freezeUser(user1);

        (uint256 frozenAt, bool canRecover) = hub.getFreezeInfo(user1);
        assertEq(frozenAt, block.timestamp);
        assertFalse(canRecover);
    }

    function test_freezeUser_revert_notCompliance() public {
        vm.prank(user1);
        vm.expectRevert();
        hub.freezeUser(user2);
    }

    function test_freezeUser_revert_invalidAddress() public {
        vm.prank(compliance);
        vm.expectRevert(RewarderHub.InvalidAddress.selector);
        hub.freezeUser(address(0));
    }

    function test_freezeUser_revert_alreadyFrozen() public {
        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.prank(compliance);
        vm.expectRevert(RewarderHub.UserAlreadyFrozen.selector);
        hub.freezeUser(user1);
    }

    /* -------------------------------------------------------------------------- */
    /*                                unfreezeUser                                 */
    /* -------------------------------------------------------------------------- */

    function test_unfreezeUser_success() public {
        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.expectEmit(true, true, true, true);
        emit RewarderHub.UserUnfrozen(user1);

        vm.prank(compliance);
        hub.unfreezeUser(user1);

        (uint256 frozenAt,) = hub.getFreezeInfo(user1);
        assertEq(frozenAt, 0);
    }

    function test_unfreezeUser_revert_notCompliance() public {
        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.prank(user1);
        vm.expectRevert();
        hub.unfreezeUser(user1);
    }

    function test_unfreezeUser_revert_notFrozen() public {
        vm.prank(compliance);
        vm.expectRevert(RewarderHub.UserNotFrozen.selector);
        hub.unfreezeUser(user1);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Frozen user cannot claim                         */
    /* -------------------------------------------------------------------------- */

    function test_claim_revert_userFrozen() public {
        _pushReward(user1, 100e18);

        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.prank(user1);
        vm.expectRevert(RewarderHub.UserIsFrozen.selector);
        hub.claim(address(token));
    }

    function test_claimBatch_revert_userFrozen() public {
        _pushReward(user1, 100e18);

        vm.prank(compliance);
        hub.freezeUser(user1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        vm.prank(user1);
        vm.expectRevert(RewarderHub.UserIsFrozen.selector);
        hub.claimBatch(tokens);
    }

    function test_claim_success_afterUnfreeze() public {
        _pushReward(user1, 100e18);

        // Freeze
        vm.prank(compliance);
        hub.freezeUser(user1);

        // Unfreeze
        vm.prank(compliance);
        hub.unfreezeUser(user1);

        // Can claim again
        vm.prank(user1);
        hub.claim(address(token));

        assertEq(token.balanceOf(user1), 100e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                            recoverFrozenFunds                               */
    /* -------------------------------------------------------------------------- */

    function test_recoverFrozenFunds_success() public {
        _pushReward(user1, 100e18);

        vm.prank(compliance);
        hub.freezeUser(user1);

        // Warp past freeze duration
        vm.warp(block.timestamp + hub.FREEZE_DURATION() + 1);

        address recipient = makeAddr("recipient");

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});

        vm.expectEmit(true, true, true, true);
        emit RewarderHub.FrozenFundsRecovered(user1, address(token), 100e18, recipient);

        vm.prank(compliance);
        hub.recoverFrozenFunds(ops, recipient);

        assertEq(token.balanceOf(recipient), 100e18);
        assertEq(hub.getClaimable(user1, address(token)), 0);
    }

    function test_recoverFrozenFunds_multipleOps() public {
        _pushReward(user1, 100e18);

        vm.prank(rewarder);
        hub.pushReward(user1, 50e18, address(token2), bank, attestation);

        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.warp(block.timestamp + hub.FREEZE_DURATION() + 1);

        address recipient = makeAddr("recipient");

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](2);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});
        ops[1] = FrozenFundsRecoverOp({wallet: user1, token: address(token2)});

        vm.prank(compliance);
        hub.recoverFrozenFunds(ops, recipient);

        assertEq(token.balanceOf(recipient), 100e18);
        assertEq(token2.balanceOf(recipient), 50e18);
    }

    function test_recoverFrozenFunds_multipleUsers() public {
        _pushReward(user1, 100e18);
        _pushReward(user2, 200e18);

        vm.startPrank(compliance);
        hub.freezeUser(user1);
        hub.freezeUser(user2);
        vm.stopPrank();

        vm.warp(block.timestamp + hub.FREEZE_DURATION() + 1);

        address recipient = makeAddr("recipient");

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](2);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});
        ops[1] = FrozenFundsRecoverOp({wallet: user2, token: address(token)});

        vm.prank(compliance);
        hub.recoverFrozenFunds(ops, recipient);

        assertEq(token.balanceOf(recipient), 300e18);
    }

    function test_recoverFrozenFunds_skipsZeroBalance() public {
        // Freeze user with no balance
        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.warp(block.timestamp + hub.FREEZE_DURATION() + 1);

        address recipient = makeAddr("recipient");

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});

        // Should not revert, just skip
        vm.prank(compliance);
        hub.recoverFrozenFunds(ops, recipient);

        assertEq(token.balanceOf(recipient), 0);
    }

    function test_recoverFrozenFunds_revert_notCompliance() public {
        _pushReward(user1, 100e18);

        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.warp(block.timestamp + hub.FREEZE_DURATION() + 1);

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});

        vm.prank(user1);
        vm.expectRevert();
        hub.recoverFrozenFunds(ops, user1);
    }

    function test_recoverFrozenFunds_revert_invalidRecipient() public {
        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.warp(block.timestamp + hub.FREEZE_DURATION() + 1);

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});

        vm.prank(compliance);
        vm.expectRevert(RewarderHub.InvalidAddress.selector);
        hub.recoverFrozenFunds(ops, address(0));
    }

    function test_recoverFrozenFunds_revert_notFrozen() public {
        _pushReward(user1, 100e18);

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});

        vm.prank(compliance);
        vm.expectRevert(RewarderHub.UserNotFrozen.selector);
        hub.recoverFrozenFunds(ops, makeAddr("recipient"));
    }

    function test_recoverFrozenFunds_revert_freezePeriodNotElapsed() public {
        _pushReward(user1, 100e18);

        vm.prank(compliance);
        hub.freezeUser(user1);

        // Only warp 30 days (not enough)
        vm.warp(block.timestamp + 30 days);

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});

        vm.prank(compliance);
        vm.expectRevert(RewarderHub.FreezePeriodNotElapsed.selector);
        hub.recoverFrozenFunds(ops, makeAddr("recipient"));
    }

    function test_recoverFrozenFunds_exactlyAtDuration() public {
        _pushReward(user1, 100e18);

        vm.prank(compliance);
        hub.freezeUser(user1);

        // Warp exactly to freeze duration (should still fail - needs to be past)
        vm.warp(block.timestamp + hub.FREEZE_DURATION());

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user1, token: address(token)});

        // At exactly FREEZE_DURATION, block.timestamp < frozenAt + FREEZE_DURATION is false
        // So it should pass
        vm.prank(compliance);
        hub.recoverFrozenFunds(ops, makeAddr("recipient"));
    }

    /* -------------------------------------------------------------------------- */
    /*                               getFreezeInfo                                 */
    /* -------------------------------------------------------------------------- */

    function test_getFreezeInfo_notFrozen() public view {
        (uint256 frozenAt, bool canRecover) = hub.getFreezeInfo(user1);
        assertEq(frozenAt, 0);
        assertFalse(canRecover);
    }

    function test_getFreezeInfo_frozenButCannotRecover() public {
        vm.prank(compliance);
        hub.freezeUser(user1);

        (uint256 frozenAt, bool canRecover) = hub.getFreezeInfo(user1);
        assertEq(frozenAt, block.timestamp);
        assertFalse(canRecover);
    }

    function test_getFreezeInfo_canRecover() public {
        uint256 freezeTime = block.timestamp;

        vm.prank(compliance);
        hub.freezeUser(user1);

        vm.warp(block.timestamp + hub.FREEZE_DURATION());

        (uint256 frozenAt, bool canRecover) = hub.getFreezeInfo(user1);
        assertEq(frozenAt, freezeTime);
        assertTrue(canRecover);
    }
}
