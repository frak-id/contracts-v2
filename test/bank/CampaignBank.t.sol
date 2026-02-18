// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CAMPAIGN_BANK_MANAGER_ROLE, CampaignBank} from "src/bank/CampaignBank.sol";

/// @title CampaignBankTest
/// @notice Comprehensive tests for CampaignBank contract
contract CampaignBankTest is Test {
    using LibClone for address;

    CampaignBank public campaignBank;
    CampaignBank public implementation;
    MockErc20 public token;
    MockErc20 public token2;

    address public owner = makeAddr("owner");
    address public manager = makeAddr("manager");
    address public rewarderHub = makeAddr("rewarderHub");
    address public user = makeAddr("user");

    function setUp() public {
        // Deploy implementation and clone
        implementation = new CampaignBank();
        campaignBank = CampaignBank(address(implementation).clone());
        campaignBank.init(owner, rewarderHub);

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
    /*                              Initialization                                */
    /* -------------------------------------------------------------------------- */

    function test_init_setsOwner() public view {
        assertEq(campaignBank.owner(), owner);
    }

    function test_init_grantsManagerRole() public view {
        assertTrue(campaignBank.hasAnyRole(owner, CAMPAIGN_BANK_MANAGER_ROLE));
    }

    function test_init_revert_invalidRewarderHub() public {
        CampaignBank newBank = CampaignBank(address(implementation).clone());
        vm.expectRevert(CampaignBank.InvalidAddress.selector);
        newBank.init(owner, address(0));
    }

    function test_init_revert_alreadyInitialized() public {
        vm.expectRevert();
        campaignBank.init(owner, rewarderHub);
    }

    function test_implementation_cannotBeInitialized() public {
        vm.expectRevert();
        implementation.init(owner, rewarderHub);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Distribution Control                              */
    /* -------------------------------------------------------------------------- */

    function test_setOpen_enable() public {
        vm.expectEmit(false, false, false, true);
        emit CampaignBank.BankStateUpdated(true);

        vm.prank(owner);
        campaignBank.setOpen(true);

        assertTrue(campaignBank.isOpen());
    }

    function test_setOpen_disable() public {
        vm.prank(owner);
        campaignBank.setOpen(true);

        vm.prank(owner);
        campaignBank.setOpen(false);

        assertFalse(campaignBank.isOpen());
    }

    function test_setOpen_byManager() public {
        vm.prank(manager);
        campaignBank.setOpen(true);

        assertTrue(campaignBank.isOpen());
    }

    function test_setOpen_revert_notAuthorized() public {
        vm.prank(user);
        vm.expectRevert();
        campaignBank.setOpen(true);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Allowance Management                              */
    /* -------------------------------------------------------------------------- */

    function test_updateAllowance_success() public {
        // Enable distribution first
        vm.prank(owner);
        campaignBank.setOpen(true);

        vm.expectEmit(true, false, false, true);
        emit CampaignBank.AllowanceUpdated(address(token), 1000e18);

        vm.prank(owner);
        campaignBank.updateAllowance(address(token), 1000e18);

        assertEq(campaignBank.getAllowance(address(token)), 1000e18);
        assertEq(token.allowance(address(campaignBank), rewarderHub), 1000e18);
    }

    function test_updateAllowance_byManager() public {
        vm.prank(owner);
        campaignBank.setOpen(true);

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
        campaignBank.setOpen(true);

        vm.prank(user);
        vm.expectRevert();
        campaignBank.updateAllowance(address(token), 1000e18);
    }

    function test_updateAllowances_multiple() public {
        vm.prank(owner);
        campaignBank.setOpen(true);

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
        campaignBank.setOpen(true);

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
        campaignBank.setOpen(true);
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
        campaignBank.setOpen(true);
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
        campaignBank.setOpen(true);

        vm.prank(owner);
        campaignBank.updateAllowance(address(token), 1000e18);

        // Manager cannot revoke (only owner)
        vm.prank(manager);
        vm.expectRevert();
        campaignBank.revokeAllowance(address(token));
    }

    function test_revokeAllowances_success() public {
        // Setup: enable and set allowances for multiple tokens
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        campaignBank.updateAllowance(address(token2), 2000e18);
        vm.stopPrank();

        // Verify allowances are set
        assertEq(campaignBank.getAllowance(address(token)), 1000e18);
        assertEq(campaignBank.getAllowance(address(token2)), 2000e18);

        // Revoke both
        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        vm.prank(owner);
        campaignBank.revokeAllowances(tokens);

        assertEq(campaignBank.getAllowance(address(token)), 0);
        assertEq(campaignBank.getAllowance(address(token2)), 0);
    }

    function test_revokeAllowances_emitsEvents() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        campaignBank.updateAllowance(address(token2), 2000e18);
        vm.stopPrank();

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        vm.expectEmit(true, false, false, true);
        emit CampaignBank.AllowanceUpdated(address(token), 0);

        vm.expectEmit(true, false, false, true);
        emit CampaignBank.AllowanceUpdated(address(token2), 0);

        vm.prank(owner);
        campaignBank.revokeAllowances(tokens);
    }

    function test_revokeAllowances_revert_notOwner() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        vm.stopPrank();

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        // Manager cannot revoke (only owner)
        vm.prank(manager);
        vm.expectRevert();
        campaignBank.revokeAllowances(tokens);
    }

    function test_revokeAllowances_emptyArray() public {
        address[] memory tokens = new address[](0);

        // Should not revert with empty array
        vm.prank(owner);
        campaignBank.revokeAllowances(tokens);
    }

    /* -------------------------------------------------------------------------- */
    /*                              View Functions                                */
    /* -------------------------------------------------------------------------- */

    function test_getAllowance_returnsCorrectValue() public {
        vm.prank(owner);
        campaignBank.setOpen(true);

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

    function test_isOpen_default() public view {
        assertFalse(campaignBank.isOpen());
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
        campaignBank.setOpen(true);

        vm.prank(owner);
        campaignBank.updateAllowance(address(token), amount);

        assertEq(campaignBank.getAllowance(address(token)), amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                    Security Edge Cases - Array Mismatch                    */
    /* -------------------------------------------------------------------------- */

    function test_updateAllowances_revert_arrayLengthMismatch_tokensLonger() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(token2);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        vm.prank(owner);
        vm.expectRevert(CampaignBank.ArrayLengthMismatch.selector);
        campaignBank.updateAllowances(tokens, amounts);
    }

    function test_updateAllowances_revert_arrayLengthMismatch_amountsLonger() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e18;
        amounts[1] = 2000e18;

        vm.prank(owner);
        vm.expectRevert(CampaignBank.ArrayLengthMismatch.selector);
        campaignBank.updateAllowances(tokens, amounts);
    }

    function test_updateAllowances_emptyArrays() public {
        vm.prank(owner);
        campaignBank.setOpen(true);

        address[] memory tokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(owner);
        campaignBank.updateAllowances(tokens, amounts);
    }

    /* -------------------------------------------------------------------------- */
    /*                 Security Edge Cases - Closed Bank Pullability              */
    /* -------------------------------------------------------------------------- */

    function test_closedBank_existingAllowanceStillUsable() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        campaignBank.setOpen(false);
        vm.stopPrank();

        assertFalse(campaignBank.isOpen());
        assertEq(token.balanceOf(address(campaignBank)), 1000e18);

        vm.prank(rewarderHub);
        token.transferFrom(address(campaignBank), rewarderHub, 300e18);

        assertEq(token.balanceOf(rewarderHub), 300e18);
        assertEq(token.balanceOf(address(campaignBank)), 700e18);
    }

    function test_closedBank_cannotUpdateAllowance() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.setOpen(false);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(CampaignBank.BankIsClosed.selector);
        campaignBank.updateAllowance(address(token), 1000e18);
    }

    function test_closedBank_canWithdrawAfterClose() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        campaignBank.setOpen(false);
        campaignBank.withdraw(address(token), 400e18, user);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 400e18);
        assertEq(token.balanceOf(address(campaignBank)), 600e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                 Security Edge Cases - Initialization Security              */
    /* -------------------------------------------------------------------------- */

    function test_init_zeroOwnerAccepted() public {
        CampaignBank newBank = CampaignBank(address(implementation).clone());

        // Solady's OwnableRoles does not revert on address(0) ownership transfer
        // This means a zero-owner bank becomes permanently ownerless
        newBank.init(address(0), rewarderHub);

        assertEq(newBank.owner(), address(0));
    }

    function test_init_ownerHasManagerRole() public view {
        assertTrue(campaignBank.hasAnyRole(owner, CAMPAIGN_BANK_MANAGER_ROLE));
    }

    /* -------------------------------------------------------------------------- */
    /*                Security Edge Cases - Role Access Control                   */
    /* -------------------------------------------------------------------------- */

    function test_managerCannotRevokeAllowance() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        vm.stopPrank();

        vm.prank(manager);
        vm.expectRevert();
        campaignBank.revokeAllowance(address(token));
    }

    function test_managerCannotRevokeAllowances() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        vm.stopPrank();

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        vm.prank(manager);
        vm.expectRevert();
        campaignBank.revokeAllowances(tokens);
    }

    function test_randomUserCannotDeposit() public {
        address randomUser = makeAddr("randomUser");
        token.mint(randomUser, 1000e18);

        vm.startPrank(randomUser);
        token.approve(address(campaignBank), 1000e18);
        vm.expectRevert();
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();
    }

    function test_randomUserCannotSetOpen() public {
        address randomUser = makeAddr("randomUser");

        vm.prank(randomUser);
        vm.expectRevert();
        campaignBank.setOpen(true);
    }

    /* -------------------------------------------------------------------------- */
    /*                 Security Edge Cases - State Transitions                    */
    /* -------------------------------------------------------------------------- */

    function test_setOpen_toggleMultipleTimes() public {
        vm.prank(owner);
        campaignBank.setOpen(true);
        assertTrue(campaignBank.isOpen());

        vm.prank(owner);
        campaignBank.setOpen(false);
        assertFalse(campaignBank.isOpen());

        vm.prank(owner);
        campaignBank.setOpen(true);
        assertTrue(campaignBank.isOpen());

        vm.prank(owner);
        campaignBank.setOpen(false);
        assertFalse(campaignBank.isOpen());
    }

    function test_deposit_whileBankClosed() public {
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        assertEq(campaignBank.getBalance(address(token)), 1000e18);
    }

    function test_deposit_whileBankOpen() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        vm.stopPrank();

        assertEq(campaignBank.getBalance(address(token)), 1000e18);
    }

    function test_withdraw_fullBalance() public {
        vm.startPrank(owner);
        token.approve(address(campaignBank), 1000e18);
        campaignBank.deposit(address(token), 1000e18);
        campaignBank.withdraw(address(token), 1000e18, user);
        vm.stopPrank();

        assertEq(campaignBank.getBalance(address(token)), 0);
        assertEq(token.balanceOf(user), 1000e18);
    }

    /* -------------------------------------------------------------------------- */
    /*              Security Edge Cases - Allowance Management                    */
    /* -------------------------------------------------------------------------- */

    function test_updateAllowance_overwritePreviousAllowance() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        campaignBank.updateAllowance(address(token), 500e18);
        vm.stopPrank();

        assertEq(campaignBank.getAllowance(address(token)), 500e18);
    }

    function test_updateAllowance_setToZero() public {
        vm.startPrank(owner);
        campaignBank.setOpen(true);
        campaignBank.updateAllowance(address(token), 1000e18);
        campaignBank.updateAllowance(address(token), 0);
        vm.stopPrank();

        assertEq(campaignBank.getAllowance(address(token)), 0);
    }

    function test_revokeAllowance_whenNoAllowanceSet() public {
        assertEq(campaignBank.getAllowance(address(token)), 0);

        vm.prank(owner);
        campaignBank.revokeAllowance(address(token));

        assertEq(campaignBank.getAllowance(address(token)), 0);
    }
}
