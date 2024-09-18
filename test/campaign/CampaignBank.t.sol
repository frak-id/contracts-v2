// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "../interaction/InteractionTest.sol";
import {MockErc20} from "../utils/MockErc20.sol";
import {Test} from "forge-std/Test.sol";
import {CampaignBank} from "src/campaign/CampaignBank.sol";
import {PRODUCT_TYPE_PRESS} from "src/constants/ProductTypes.sol";
import {CAMPAIGN_MANAGER_ROLE, PRODUCT_MANAGER_ROLE} from "src/constants/Roles.sol";
import {PushPullModule} from "src/modules/PushPullModule.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";

contract CampaignBankTest is Test {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    address internal owner = makeAddr("owner");
    address internal productOwner = makeAddr("productOwner");
    address internal productManager = makeAddr("productManager");
    address internal campaignManager = makeAddr("campaignManager");
    address internal campaign = makeAddr("campaign");

    /// @dev Comnponent required to test the bank
    ProductRegistry private productRegistry = new ProductRegistry(owner);
    ProductAdministratorRegistry private adminRegistry = new ProductAdministratorRegistry(productRegistry);

    /// @dev A mocked erc20 token
    MockErc20 private token = new MockErc20();

    /// @dev The bank we will test
    CampaignBank private campaignBank;

    function setUp() public {
        // Setup content with allowance for the operator
        vm.prank(owner);
        uint256 productId = productRegistry.mint(PRODUCT_TYPE_PRESS, "name", "press-domain", productOwner);

        // Grant the right roles to the product interaction manager
        vm.startPrank(productOwner);
        adminRegistry.grantRoles(productId, productManager, PRODUCT_MANAGER_ROLE);
        adminRegistry.grantRoles(productId, campaignManager, CAMPAIGN_MANAGER_ROLE);
        vm.stopPrank();

        // Deploy the bank
        campaignBank = new CampaignBank(adminRegistry, productId, address(token));

        // Mink a few tokens
        token.mint(address(campaignBank), 100 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 States test                                */
    /* -------------------------------------------------------------------------- */

    function test_startDisabled() public view {
        assertFalse(campaignBank.isDistributionEnabled());
    }

    function test_campaignAllowance() public {
        assertFalse(campaignBank.isCampaignAllowed(campaign));

        // The campaign manager can change the status
        vm.prank(campaignManager);
        campaignBank.updateCampaignAllowance(campaign, true);

        assertTrue(campaignBank.isCampaignAllowed(campaign));

        // No random ppl could change this status
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        campaignBank.updateCampaignAllowance(campaign, true);

        // The product manager can';t change the status
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        vm.prank(productManager);
        campaignBank.updateCampaignAllowance(campaign, true);

        // The product owner can change the status
        vm.prank(productOwner);
        campaignBank.updateCampaignAllowance(campaign, false);

        assertFalse(campaignBank.isCampaignAllowed(campaign));
    }

    function test_distributionState() public {
        assertFalse(campaignBank.isDistributionEnabled());

        // The product manager can change the status
        vm.prank(productManager);
        campaignBank.updateDistributionState(true);

        assertTrue(campaignBank.isDistributionEnabled());

        // No random ppl could change this status
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        campaignBank.updateDistributionState(true);

        // The campaign manager can't change the status
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        vm.prank(campaignManager);
        campaignBank.updateDistributionState(true);

        // The product owner can change the status
        vm.prank(productOwner);
        campaignBank.updateDistributionState(false);

        assertFalse(campaignBank.isDistributionEnabled());
    }

    /* -------------------------------------------------------------------------- */
    /*                                Reward tests                                */
    /* -------------------------------------------------------------------------- */

    function test_distributeRewards() public {
        // Get some rewards
        PushPullModule.Reward[] memory rewards = _getRewards();

        // The campaign manager can't distribute rewards
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        vm.prank(campaignManager);
        campaignBank.pushRewards(rewards);

        // The product manager can't distribute rewards
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        vm.prank(productManager);
        campaignBank.pushRewards(rewards);

        // The product owner can't distribute rewards
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        vm.prank(productOwner);
        campaignBank.pushRewards(rewards);

        // If campaignj not allowed, it can't distribute rewards
        vm.prank(campaignManager);
        campaignBank.updateCampaignAllowance(campaign, false);
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        campaignBank.pushRewards(rewards);

        // If campaign allowed, it can distribute rewards
        vm.prank(campaignManager);
        campaignBank.updateCampaignAllowance(campaign, true);

        // If the bank isnt running, cant distribute rewards
        vm.prank(campaign);
        vm.expectRevert(CampaignBank.BankIsntOpen.selector);
        campaignBank.pushRewards(rewards);

        // If the bank isnt running, cant distribute rewards
        vm.prank(productOwner);
        campaignBank.updateDistributionState(true);

        // Push  the rewards
        vm.prank(campaign);
        campaignBank.pushRewards(rewards);

        assertGt(token.balanceOf(address(campaignBank)), 0);
        assertGt(campaignBank.getTotalPending(), 0);

        // Assert that alice and bob can claim their rewards
        assertEq(campaignBank.getPendingAmount(alice), 1 ether);
        assertEq(campaignBank.getPendingAmount(bob), 1 ether);
        campaignBank.pullReward(alice);
        campaignBank.pullReward(bob);

        assertEq(campaignBank.getPendingAmount(alice), 0);
        assertEq(campaignBank.getPendingAmount(bob), 0);
        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(token.balanceOf(bob), 1 ether);
    }

    function test_withdraw() public {
        // Random ppl can't withraw
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        campaignBank.withdraw();

        // The campaign manager can't withdraw
        vm.expectRevert(CampaignBank.Unauthorized.selector);
        vm.prank(campaignManager);
        campaignBank.withdraw();

        // If the distribution is enabled, it can't withdraw
        vm.prank(productManager);
        campaignBank.updateDistributionState(true);
        vm.prank(productManager);
        vm.expectRevert(CampaignBank.BankIsStillOpen.selector);
        campaignBank.withdraw();

        uint256 prevBalance = token.balanceOf(address(productOwner));
        uint256 prevBankBalance = token.balanceOf(address(campaignBank));

        // If the distribution is disabled, it can withdraw
        vm.prank(productOwner);
        campaignBank.updateDistributionState(false);
        vm.prank(productOwner);
        campaignBank.withdraw();

        uint256 newBalance = token.balanceOf(address(productOwner));
        uint256 newBankBalance = token.balanceOf(address(campaignBank));

        assertEq(newBankBalance, 0);
        assertEq(newBalance - prevBalance, prevBankBalance);
    }

    function test_withdraw_withPendingRewards() public {
        vm.prank(campaignManager);
        campaignBank.updateCampaignAllowance(campaign, true);
        vm.prank(productOwner);
        campaignBank.updateDistributionState(true);

        // Get some rewards
        PushPullModule.Reward[] memory rewards = _getRewards();

        vm.prank(campaign);
        campaignBank.pushRewards(rewards);

        uint256 totalPending = campaignBank.getTotalPending();
        uint256 prevBalance = token.balanceOf(address(productOwner));
        uint256 prevBankBalance = token.balanceOf(address(campaignBank));
        uint256 theoriticalClaim = prevBankBalance - totalPending;

        // If the distribution is disabled, it can withdraw
        vm.prank(productOwner);
        campaignBank.updateDistributionState(false);

        vm.prank(productOwner);
        campaignBank.withdraw();

        uint256 newBalance = token.balanceOf(address(productOwner));
        uint256 newBankBalance = token.balanceOf(address(campaignBank));

        assertEq(newBankBalance, totalPending);
        assertEq(newBalance - prevBalance, theoriticalClaim);

        // Ensure that alice and bob can still claim
        assertEq(campaignBank.getPendingAmount(alice), 1 ether);
        assertEq(campaignBank.getPendingAmount(bob), 1 ether);

        campaignBank.pullReward(alice);
        campaignBank.pullReward(bob);

        assertEq(campaignBank.getPendingAmount(alice), 0);
        assertEq(campaignBank.getPendingAmount(bob), 0);

        assertEq(token.balanceOf(address(campaignBank)), 0);
        assertEq(campaignBank.getTotalPending(), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Heleprs                                  */
    /* -------------------------------------------------------------------------- */

    // Get tesst rewards
    function _getRewards() private view returns (PushPullModule.Reward[] memory rewards) {
        rewards = new PushPullModule.Reward[](2);
        rewards[0] = PushPullModule.Reward({user: alice, amount: 1 ether});
        rewards[1] = PushPullModule.Reward({user: bob, amount: 1 ether});
    }
}
