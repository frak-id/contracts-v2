// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CAMPAIGN_EVENT_EMITTER_ROLE} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {CONTENT_TYPE_DAPP, CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {ContentRegistry, Metadata} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

contract ReferralCampaignTest is Test {
    address private owner = makeAddr("owner");
    address private emitter = makeAddr("emitter");
    address private emitterManager = makeAddr("emitterManager");

    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");
    address private delta = makeAddr("delta");

    bytes32 private referralTree = keccak256("tree");

    /// @dev A mocked erc20 token
    MockErc20 private token = new MockErc20();

    /// @dev The registry we will use
    ReferralRegistry private referralRegistry;

    /// @dev The campaign we will test
    ReferralCampaign private referralCampaign;

    function setUp() public {
        referralRegistry = new ReferralRegistry(owner);

        // Grant the right roles to the content interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(owner, REFERRAL_ALLOWANCE_MANAGER_ROLE);
        vm.prank(owner);
        referralRegistry.grantAccessToTree(referralTree, owner);

        // Our campaign
        referralCampaign = new ReferralCampaign(
            address(token), 3, 1000, 10 ether, 100 ether, referralTree, referralRegistry, owner, emitterManager
        );

        // Mint a few test tokens to the campaign
        token.mint(address(referralCampaign), 1_000 ether);
    }

    function test_init() public {
        vm.expectRevert(ReferralCampaign.InvalidConfig.selector);
        ReferralCampaign invalidCampaign = new ReferralCampaign(
            address(0), 3, 1000, 10 ether, 100 ether, referralTree, referralRegistry, owner, emitterManager
        );

        vm.expectRevert(ReferralCampaign.InvalidConfig.selector);
        invalidCampaign = new ReferralCampaign(
            address(token), 3, 5_001, 10 ether, 100 ether, referralTree, referralRegistry, owner, emitterManager
        );
    }

    function test_metadata() public view {
        (string memory name, string memory version) = referralCampaign.getMetadata();
        assertEq(name, "frak.campaign.referral");
        assertEq(version, "0.0.1");
    }

    function test_isActive() public {
        // Not enogutth token work
        deal(address(token), address(referralCampaign), 1 ether);
        assertEq(referralCampaign.isActive(), false);

        // Not Enough token work
        deal(address(token), address(referralCampaign), 101 ether);
        assertEq(referralCampaign.isActive(), true);
    }

    function test_supportContentType() public view {
        assertEq(referralCampaign.supportContentType(CONTENT_TYPE_DAPP), false);
        assertEq(referralCampaign.supportContentType(ContentTypes.wrap(uint256(1 << 9))), false);
        assertEq(referralCampaign.supportContentType(CONTENT_TYPE_PRESS), true);
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

        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 10 ether);
        assertEq(referralCampaign.getPendingAmount(charlie, address(token)), 1 ether);
        assertEq(referralCampaign.getPendingAmount(delta, address(token)), 100000000 gwei);

        // Distribute to bob
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(bob, 10 ether);

        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 10 ether);
        assertEq(referralCampaign.getPendingAmount(charlie, address(token)), 11 ether);
        assertEq(referralCampaign.getPendingAmount(delta, address(token)), 1100000000 gwei);
    }

    function test_tokenDistribution_DailyDistributionCapReached() public withReferralChain {
        // Distribute to alice 90 ether (knowing that hte cap is 100 ether, and we distribute 10% per level, so total at 99.9 ether)
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(alice, 90 ether);
        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 90 ether);

        // Case were we reach the end of the cap
        vm.expectRevert(ReferralCampaign.DailyDistributionCapReached.selector);
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(alice, 1 ether);

        // Assert that the cap is restored the day after
        uint256 currentTimestamp = block.timestamp;
        vm.warp(currentTimestamp + 1 days);
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(alice, 90 ether);
        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 180 ether);
    }

    function test_handleInteraction_doNothing() public withReferralChain withAllowedEmitter {
        bytes memory fckedUpData = hex"13";

        // Ensure we can't distribute if not allowed
        vm.expectRevert(Ownable.Unauthorized.selector);
        referralCampaign.handleInteraction(fckedUpData);

        // Ensure call won't fail with fcked up data
        vm.prank(emitter);
        referralCampaign.handleInteraction(fckedUpData);

        // Ensure no reward was added
        assertEq(referralCampaign.getPendingAmount(alice, address(token)), 0);
        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 0);
        assertEq(referralCampaign.getPendingAmount(charlie, address(token)), 0);
        assertEq(referralCampaign.getPendingAmount(delta, address(token)), 0);

        // Ensure it won't do anything if campaign stopped
        vm.prank(owner);
        referralCampaign.withdraw();
        vm.prank(emitter);
        referralCampaign.handleInteraction(fckedUpData);

        // Ensure no reward was added
        assertEq(referralCampaign.getPendingAmount(alice, address(token)), 0);
        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 0);
        assertEq(referralCampaign.getPendingAmount(charlie, address(token)), 0);
        assertEq(referralCampaign.getPendingAmount(delta, address(token)), 0);
    }

    function test_handleInteraction_sharedArticleUsed() public withReferralChain withAllowedEmitter {
        bytes memory interactionData = InteractionTypeLib.packForCampaign(PressInteractions.REFERRED, alice);

        // Ensure call won't fail with fcked up data
        vm.prank(emitter);
        referralCampaign.handleInteraction(interactionData);

        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 10 ether);
        assertEq(referralCampaign.getPendingAmount(charlie, address(token)), 1 ether);
        assertEq(referralCampaign.getPendingAmount(delta, address(token)), 100000000 gwei);

        // Ensure it won't do anything if campaign stopped
        vm.prank(owner);
        referralCampaign.withdraw();
        vm.prank(emitter);
        referralCampaign.handleInteraction(interactionData);

        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 10 ether);
        assertEq(referralCampaign.getPendingAmount(charlie, address(token)), 1 ether);
        assertEq(referralCampaign.getPendingAmount(delta, address(token)), 100000000 gwei);
    }

    function test_disallowMe() public withReferralChain withAllowedEmitter {
        bytes memory interactionData = InteractionTypeLib.packForCampaign(PressInteractions.REFERRED, alice);

        vm.prank(emitter);
        referralCampaign.disallowMe();

        vm.expectRevert(Ownable.Unauthorized.selector);
        referralCampaign.handleInteraction(interactionData);
    }

    function test_allowInteractionContract() public withReferralChain withAllowedEmitter {
        address testEmitter = makeAddr("testEmitter");

        vm.expectRevert(Ownable.Unauthorized.selector);
        referralCampaign.allowInteractionContract(testEmitter);

        vm.prank(emitterManager);
        referralCampaign.allowInteractionContract(testEmitter);

        assertTrue(referralCampaign.hasAnyRole(testEmitter, CAMPAIGN_EVENT_EMITTER_ROLE));
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

    modifier withAllowedEmitter() {
        vm.prank(emitterManager);
        referralCampaign.allowInteractionContract(emitter);
        _;
    }
}
