// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewarderHubBaseTest} from "./RewarderHub.base.t.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UPGRADE_ROLE} from "src/constants/Roles.sol";
import {RewarderHub} from "src/reward/RewarderHub.sol";

/// @title RewarderHubAdminTest
/// @notice Tests for admin functions: pushReward
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
