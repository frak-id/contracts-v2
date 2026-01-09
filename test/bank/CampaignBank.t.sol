// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {CampaignBank, CAMPAIGN_BANK_MANAGER_ROLE} from "src/bank/CampaignBank.sol";
import {MockErc20} from "../utils/MockErc20.sol";

/// @title CampaignBankTest
/// @notice Comprehensive tests for CampaignBank contract
contract CampaignBankTest is Test {
    CampaignBank public campaignBank;
    MockErc20 public token;
    MockErc20 public token2;

    address public owner = makeAddr("owner");
    address public manager = makeAddr("manager");
    address public rewarderHub = makeAddr("rewarderHub");
    address public user = makeAddr("user");

    function setUp() public {
        // Deploy bank
        campaignBank = new CampaignBank(owner, rewarderHub);

        // Deploy mock tokens
        token = new MockErc20();
        token2 = new MockErc20();

        // Grant manager role
        vm.prank(owner);
        campaignBank.grantRoles(manager, CAMPAIGN_BANK_MANAGER_ROLE);

        // Fund owner with tokens for deposits
        token.mint(owner, 1_000_000e18);
        token2.mint(owner, 1_000_000e18);
        token.mint(manager, 1_000_000e18);
        token2.mint(manager, 1_000_000e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Constructor                                   */
    /* -------------------------------------------------------------------------- */

    function test_constructor_setsOwner() public view {
        assertEq(campaignBank.owner(), owner);
    }

    function test_constructor_setsRewarderHub() public view {
        assertEq(campaignBank.REWARDER_HUB(), rewarderHub);
    }

    function test_constructor_grantsManagerRole() public view {
        assertTrue(campaignBank.hasAnyRole(owner, CAMPAIGN_BANK_MANAGER_ROLE));
    }

    function test_constructor_revert_invalidRewarderHub() public {
        vm.expectRevert(CampaignBank.InvalidAddress.selector);
        new CampaignBank(owner, address(0));
    }

    /* -------------------------------------------------------------------------- */
    /*                          Distribution Control                              */
    /* -------------------------------------------------------------------------- */

    function test_setDistributionState_enable() public {
        vm.expectEmit(false, false, false, true);
        emit CampaignBank.DistributionStateUpdated(true);

        vm.prank(owner);
        campaignBank.setDistributionState(true);

        assertTrue(campaignBank.isDistributionEnabled());
    }

    function test_setDistributionState_disable() public {
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        vm.prank(owner);
        campaignBank.setDistributionState(false);

        assertFalse(campaignBank.isDistributionEnabled());
    }

    function test_setDistributionState_byManager() public {
        vm.prank(manager);
        campaignBank.setDistributionState(true);

        assertTrue(campaignBank.isDistributionEnabled());
    }

    function test_setDistributionState_revert_notAuthorized() public {
        vm.prank(user);
        vm.expectRevert();
        campaignBank.setDistributionState(true);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Allowance Management                              */
    /* -------------------------------------------------------------------------- */

    function test_updateAllowance_success() public {
        // Enable distribution first
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        vm.expectEmit(true, false, false, true);
        emit CampaignBank.AllowanceUpdated(address(token), 1000e18);

        vm.prank(owner);
        campaignBank.updateAllowance(address(token), 1000e18);

        assertEq(campaignBank.getAllowance(address(token)), 1000e18);
        assertEq(token.allowance(address(campaignBank), rewarderHub), 1000e18);
    }

    function test_updateAllowance_byManager() public {
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        vm.prank(manager);
        campaignBank.updateAllowance(address(token), 1000e18);

        assertEq(campaignBank.getAllowance(address(token)), 1000e18);
    }

    function test_updateAllowance_revert_bankClosed() public {
        // Distribution not enabled
        vm.prank(owner);
        vm.expectRevert(CampaignBank.BankIsClosed.selector);
        campaignBank.updateAllowance(address(token), 1000e18);
    }

    function test_updateAllowance_revert_notAuthorized() public {
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        vm.prank(user);
        vm.expectRevert();
        campaignBank.updateAllowance(address(token), 1000e18);
    }

    function test_updateAllowances_multiple() public {
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e18;
        amounts[1] = 2000e18;

        vm.prank(owner);
        campaignBank.updateAllowances(tokens, amounts);

        assertEq(campaignBank.getAllowance(address(token)), 1000e18);
        assertEq(campaignBank.getAllowance(address(token2)), 2000e18);
    }

    function test_updateAllowances_emitsEvents() public {
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e18;
        amounts[1] = 2000e18;

        vm.expectEmit(true, false, false, true);
        emit CampaignBank.AllowanceUpdated(address(token), 1000e18);

        vm.expectEmit(true, false, false, true);
        emit CampaignBank.AllowanceUpdated(address(token2), 2000e18);

        vm.prank(owner);
        campaignBank.updateAllowances(tokens, amounts);
    }

    function test_updateAllowances_revert_bankClosed() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        vm.prank(owner);
        vm.expectRevert(CampaignBank.BankIsClosed.selector);
        campaignBank.updateAllowances(tokens, amounts);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Deposit & Withdrawal                             */
    /* -------------------------------------------------------------------------- */

    function test_deposit_success() public {
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);

        vm.expectEmit(true, false, false, true);
        emit CampaignBank.Deposited(address(token), 1000e18);

        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        assertEq(campaignBank.getBalance(address(token)), 1000e18);
    }

    function test_deposit_byManager() public {
        vm.startPrank(manager);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        assertEq(campaignBank.getBalance(address(token)), 1000e18);
    }

    function test_deposit_revert_notAuthorized() public {
        token.mint(user, 1000e18);

        vm.startPrank(user);
        token.approve(address(campaignBank), 1000e18);

        vm.expectRevert();
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();
    }

    function test_withdraw_success() public {
        // Deposit first
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        // Distribution must be disabled to withdraw
        uint256 balanceBefore = token.balanceOf(user);

        vm.expectEmit(true, false, false, true);
        emit CampaignBank.Withdrawn(address(token), 500e18, user);

        vm.prank(owner);
        campaignBank.withdraw(address(token), 500e18, user);

        assertEq(token.balanceOf(user), balanceBefore + 500e18);
        assertEq(campaignBank.getBalance(address(token)), 500e18);
    }

    function test_withdraw_byManager() public {
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        vm.prank(manager);
        campaignBank.withdraw(address(token), 500e18, user);

        assertEq(token.balanceOf(user), 500e18);
    }

    function test_withdraw_revert_bankStillOpen() public {
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        campaignBank.setDistributionState(true);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(CampaignBank.BankIsStillOpen.selector);
        campaignBank.withdraw(address(token), 500e18, user);
    }

    function test_withdraw_revert_invalidAddress() public {
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(CampaignBank.InvalidAddress.selector);
        campaignBank.withdraw(address(token), 500e18, address(0));
    }

    function test_withdraw_revert_notAuthorized() public {
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        vm.prank(user);
        vm.expectRevert();
        campaignBank.withdraw(address(token), 500e18, user);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Emergency Functions                              */
    /* -------------------------------------------------------------------------- */

    function test_revokeAllowance_success() public {
        // Setup: enable distribution and set allowance
        vm.startPrank(owner);
        campaignBank.setDistributionState(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        vm.stopPrank();

        // Owner can revoke even when distribution is enabled
        vm.expectEmit(true, false, false, true);
        emit CampaignBank.AllowanceUpdated(address(token), 0);

        vm.prank(owner);
        campaignBank.revokeAllowance(address(token));

        assertEq(campaignBank.getAllowance(address(token)), 0);
    }

    function test_revokeAllowance_revert_notOwner() public {
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        vm.prank(owner);
        campaignBank.updateAllowance(address(token), 1000e18);

        // Manager cannot revoke (only owner)
        vm.prank(manager);
        vm.expectRevert();
        campaignBank.revokeAllowance(address(token));
    }

    /* -------------------------------------------------------------------------- */
    /*                              View Functions                                */
    /* -------------------------------------------------------------------------- */

    function test_getAllowance_returnsCorrectValue() public {
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        vm.prank(owner);
        campaignBank.updateAllowance(address(token), 1000e18);

        assertEq(campaignBank.getAllowance(address(token)), 1000e18);
    }

    function test_getAllowance_zeroWhenNotSet() public view {
        assertEq(campaignBank.getAllowance(address(token)), 0);
    }

    function test_getBalance_returnsCorrectValue() public {
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        assertEq(campaignBank.getBalance(address(token)), 1000e18);
    }

    function test_getBalance_zeroWhenEmpty() public view {
        assertEq(campaignBank.getBalance(address(token)), 0);
    }

    function test_isDistributionEnabled_default() public view {
        assertFalse(campaignBank.isDistributionEnabled());
    }

    /* -------------------------------------------------------------------------- */
    /*                              Fuzz Tests                                    */
    /* -------------------------------------------------------------------------- */

    function testFuzz_deposit_amounts(uint96 amount) public {
        vm.assume(amount > 0 && amount <= 1_000_000e18);

        vm.startPrank(owner);
        token.approve(address(campaignBank), amount);
        campaignBank.deposit(address(token), amount);
        vm.stopPrank();

        assertEq(campaignBank.getBalance(address(token)), amount);
    }

    function testFuzz_withdraw_partialAmounts(uint96 depositAmount, uint96 withdrawAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= 1_000_000e18);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);

        vm.startPrank(owner);
        token.approve(address(campaignBank), depositAmount);
        campaignBank.deposit(address(token), depositAmount);
        campaignBank.withdraw(address(token), withdrawAmount, user);
        vm.stopPrank();

        assertEq(campaignBank.getBalance(address(token)), depositAmount - withdrawAmount);
        assertEq(token.balanceOf(user), withdrawAmount);
    }

    function testFuzz_updateAllowance_amounts(uint96 amount) public {
        vm.prank(owner);
        campaignBank.setDistributionState(true);

        vm.prank(owner);
        campaignBank.updateAllowance(address(token), amount);

        assertEq(campaignBank.getAllowance(address(token)), amount);
    }
}
