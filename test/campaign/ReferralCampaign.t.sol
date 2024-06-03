// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {CONTENT_TYPE_DAPP, CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {InteractionEncoderLib} from "src/interaction/lib/InteractionEncoderLib.sol";
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

    // The registry we will use
    ReferralRegistry private referralRegistry;

    // The campaign we will test
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
            address(token), 3, 500, 10 ether, 100 ether, referralTree, referralRegistry, owner, emitterManager
        );

        // Mint a few test tokens to the campaign
        token.mint(address(referralCampaign), 1_000 ether);

        // Set the campaign as active by default
        vm.prank(owner);
        referralCampaign.setActive(true);
    }

    function test_isActive() public {
        // Test start with campaign active
        assertEq(referralCampaign.isActive(), true);

        // Not enogutth token work
        deal(address(token), address(referralCampaign), 1 ether);
        assertEq(referralCampaign.isActive(), false);

        // Disable works
        vm.prank(owner);
        referralCampaign.setActive(false);
        assertEq(referralCampaign.isActive(), false);
    }

    function test_supportContentType() public view {
        assertEq(referralCampaign.supportContentType(CONTENT_TYPE_DAPP), false);
        assertEq(referralCampaign.supportContentType(ContentTypes.wrap(bytes32(uint256(1 << 9)))), false);
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
        // Distribute to alice
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(alice, 10 ether);

        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 10 ether);
        assertEq(referralCampaign.getPendingAmount(charlie, address(token)), 500000000 gwei);
        assertEq(referralCampaign.getPendingAmount(delta, address(token)), 25000000 gwei);

        // Distribute to bob
        vm.prank(owner);
        referralCampaign.distributeTokenToUserReferrers(bob, 10 ether);

        assertEq(referralCampaign.getPendingAmount(bob, address(token)), 10 ether);
        assertEq(referralCampaign.getPendingAmount(charlie, address(token)), 10500000000 gwei);
        assertEq(referralCampaign.getPendingAmount(delta, address(token)), 525000000 gwei);
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
