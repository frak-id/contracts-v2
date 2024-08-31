// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "../interaction/InteractionTest.sol";
import {MockErc20} from "../utils/MockErc20.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {InteractionTypeLib, ReferralInteractions} from "src/constants/InteractionType.sol";
import {
    PRODUCT_TYPE_DAPP,
    PRODUCT_TYPE_FEATURE_REFERRAL,
    PRODUCT_TYPE_PRESS,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {Metadata, ProductRegistry} from "src/registry/ProductRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

contract ReferralCampaignTest is InteractionTest {
    address private emitter;

    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");
    address private delta = makeAddr("delta");

    /// @dev A mocked erc20 token
    MockErc20 private token = new MockErc20();

    /// @dev The campaign we will test
    ReferralCampaign private referralCampaign;

    function setUp() public {
        vm.prank(owner);
        productId =
            productRegistry.mint(PRODUCT_TYPE_PRESS | PRODUCT_TYPE_FEATURE_REFERRAL, "name", "press-domain", owner);
        vm.prank(owner);
        productRegistry.setApprovalForAll(operator, true);

        _initInteractionTest();

        // Grant the right roles to the product interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(owner, REFERRAL_ALLOWANCE_MANAGER_ROLE);
        vm.prank(owner);
        referralRegistry.grantAccessToTree(referralTree, owner);

        // Our campaign
        ReferralCampaign.CampaignConfig memory config = ReferralCampaign.CampaignConfig({
            token: address(token),
            initialReward: 10 ether,
            userRewardPercent: 5_000, // 50%
            distributionCapPeriod: 1 days,
            distributionCap: 100 ether,
            startDate: uint48(0),
            endDate: uint48(0),
            name: "test"
        });
        referralCampaign = new ReferralCampaign(config, referralRegistry, adminRegistry, owner, productInteraction);

        // Mint a few test tokens to the campaign
        token.mint(address(referralCampaign), 1_000 ether);

        emitter = address(productInteraction);

        // Fake the timestamp
        vm.warp(100);
    }

    function performSingleInteraction() internal override {
        vm.skip(true);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory a, bytes memory b) {
        vm.skip(true);
        // just for linter stuff
        a = abi.encodePacked("a");
        b = abi.encodePacked("b");
    }

    function test_init() public {
        ReferralCampaign.CampaignConfig memory config = ReferralCampaign.CampaignConfig({
            token: address(0),
            initialReward: 10 ether,
            userRewardPercent: 5_000, // 50%
            distributionCapPeriod: 1 days,
            distributionCap: 100 ether,
            startDate: uint48(0),
            endDate: uint48(0),
            name: "test"
        });

        vm.expectRevert(ReferralCampaign.InvalidConfig.selector);
        new ReferralCampaign(config, referralRegistry, adminRegistry, owner, productInteraction);
    }

    function test_metadata() public view {
        (string memory name, string memory version) = referralCampaign.getMetadata();
        assertEq(name, "frak.campaign.referral");
        assertEq(version, "0.0.1");
    }

    function test_isActive() public {
        // Not enoguth token work
        deal(address(token), address(referralCampaign), 1 ether);
        assertEq(referralCampaign.isActive(), false);

        // Enough token work
        deal(address(token), address(referralCampaign), 101 ether);
        assertEq(referralCampaign.isActive(), true);

        // Not running work
        vm.prank(owner);
        referralCampaign.setRunningStatus(false);
        assertEq(referralCampaign.isActive(), false);

        // Running work
        vm.prank(owner);
        referralCampaign.setRunningStatus(true);
        assertEq(referralCampaign.isActive(), true);

        // Not started yet work
        vm.prank(owner);
        referralCampaign.setActivationDate(uint48(vm.getBlockTimestamp() + 1), 0);
        assertEq(referralCampaign.isActive(), false);

        // Ended work
        vm.prank(owner);
        referralCampaign.setActivationDate(0, uint48(vm.getBlockTimestamp() - 1));
        assertEq(referralCampaign.isActive(), false);
    }

    function test_supportProductType() public view {
        assertEq(referralCampaign.supportProductType(PRODUCT_TYPE_DAPP), false);
        assertEq(referralCampaign.supportProductType(ProductTypes.wrap(uint256(1 << 9))), false);
        assertEq(referralCampaign.supportProductType(PRODUCT_TYPE_PRESS), false);
        assertEq(referralCampaign.supportProductType(PRODUCT_TYPE_FEATURE_REFERRAL), true);
        assertEq(
            referralCampaign.supportProductType(PRODUCT_TYPE_FEATURE_REFERRAL | PRODUCT_TYPE_DAPP | PRODUCT_TYPE_PRESS),
            true
        );
    }

    function test_withdraw() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        referralCampaign.withdraw();

        vm.prank(owner);
        referralCampaign.withdraw();

        assertEq(token.balanceOf(owner), 1_000 ether);
        assertEq(token.balanceOf(address(referralCampaign)), 0);
    }

    function test_distributeTokenToUserReferrers() public withReferralChain {
        // Ensure we can't distribute if not allowed
        vm.expectRevert(Ownable.Unauthorized.selector);
        referralCampaign.distributeTokenToUserReferrers(alice, 10 ether);

        // Distribute to alice
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(alice, 10 ether);

        assertEq(referralCampaign.getPendingAmount(alice), 4 ether);
        assertEq(referralCampaign.getPendingAmount(bob), 3.2 ether);
        assertEq(referralCampaign.getPendingAmount(charlie), 0.64 ether);
        assertEq(referralCampaign.getPendingAmount(delta), 0.16 ether);

        // Distribute to bob
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(bob, 10 ether);

        assertEq(referralCampaign.getPendingAmount(bob), 7.2 ether);
        assertEq(referralCampaign.getPendingAmount(charlie), 3.84 ether);
        assertEq(referralCampaign.getPendingAmount(delta), 0.96 ether);
    }

    function test_tokenDistribution_DailyDistributionCapReached() public withReferralChain {
        // Distribute to alice 90 ether
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(alice, 99.99 ether);
        assertEq(referralCampaign.getPendingAmount(alice), 39.996 ether);

        // Case were we reach the end of the cap
        vm.expectRevert(ReferralCampaign.DistributionCapReached.selector);
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(alice, 0.1 ether);

        // Assert that the cap is restored the day after
        uint256 currentTimestamp = block.timestamp;
        vm.warp(currentTimestamp + 1 days);
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(alice, 99.99 ether);
        assertEq(referralCampaign.getPendingAmount(alice), 79.992 ether);
    }

    function test_handleInteraction_doNothing() public withReferralChain {
        bytes memory fckedUpData = hex"13";

        // Ensure we can't distribute if not allowed
        vm.expectRevert(Ownable.Unauthorized.selector);
        referralCampaign.handleInteraction(fckedUpData);

        // Ensure call won't fail with fcked up data
        vm.prank(emitter);
        referralCampaign.handleInteraction(fckedUpData);

        // Ensure no reward was added
        assertEq(referralCampaign.getPendingAmount(alice), 0);
        assertEq(referralCampaign.getPendingAmount(bob), 0);
        assertEq(referralCampaign.getPendingAmount(charlie), 0);
        assertEq(referralCampaign.getPendingAmount(delta), 0);

        // Ensure it won't do anything if campaign stopped
        vm.prank(owner);
        referralCampaign.withdraw();
        vm.prank(emitter);
        referralCampaign.handleInteraction(fckedUpData);

        // Ensure no reward was added
        assertEq(referralCampaign.getPendingAmount(alice), 0);
        assertEq(referralCampaign.getPendingAmount(bob), 0);
        assertEq(referralCampaign.getPendingAmount(charlie), 0);
        assertEq(referralCampaign.getPendingAmount(delta), 0);
    }

    function test_handleInteraction_sharedArticleUsed() public withReferralChain {
        bytes memory interactionData = InteractionTypeLib.packForCampaign(ReferralInteractions.REFERRED, alice);

        // Ensure call won't fail with fcked up data
        vm.prank(emitter);
        referralCampaign.handleInteraction(interactionData);

        assertEq(referralCampaign.getPendingAmount(alice), 4 ether);
        assertEq(referralCampaign.getPendingAmount(bob), 3.2 ether);
        assertEq(referralCampaign.getPendingAmount(charlie), 0.64 ether);
        assertEq(referralCampaign.getPendingAmount(delta), 0.16 ether);

        // Ensure it won't do anything if campaign stopped
        vm.prank(owner);
        referralCampaign.withdraw();
        vm.prank(emitter);
        vm.expectRevert();
        referralCampaign.handleInteraction(interactionData);

        assertEq(referralCampaign.getPendingAmount(alice), 4 ether);
        assertEq(referralCampaign.getPendingAmount(bob), 3.2 ether);
        assertEq(referralCampaign.getPendingAmount(charlie), 0.64 ether);
        assertEq(referralCampaign.getPendingAmount(delta), 0.16 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    modifier withReferralChain() {
        vm.startPrank(owner);
        referralRegistry.saveReferrer(referralTree, alice, bob);
        referralRegistry.saveReferrer(referralTree, bob, charlie);
        referralRegistry.saveReferrer(referralTree, charlie, delta);
        vm.stopPrank();
        _;
    }
}
