// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CAMPAIGN_EVENT_EMITTER_ROLE, MockCampaign} from "../utils/MockCampaign.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {CONTENT_TYPE_DAPP, CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {ContentInteraction} from "src/interaction/ContentInteraction.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentRegistry, Metadata} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

contract ContentInteractionManagerTest is Test {
    address private owner = makeAddr("owner");
    address private operator = makeAddr("operator");

    ContentRegistry private contentRegistry;
    ReferralRegistry private referralRegistry;

    uint256 private contentIdDapp;
    uint256 private contentIdPress;
    uint256 private contentIdUnknown;

    ContentInteractionManager private contentInteractionManager;

    function setUp() public {
        contentRegistry = new ContentRegistry(owner);
        referralRegistry = new ReferralRegistry(owner);

        address implem = address(new ContentInteractionManager(contentRegistry, referralRegistry));
        address proxy = LibClone.deployERC1967(implem);
        contentInteractionManager = ContentInteractionManager(proxy);
        contentInteractionManager.init(owner);

        // Grant the right roles to the content interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(address(contentInteractionManager), REFERRAL_ALLOWANCE_MANAGER_ROLE);

        vm.startPrank(owner);
        contentIdDapp = contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "dapp-domain");
        contentIdPress = contentRegistry.mint(CONTENT_TYPE_PRESS, "name", "press-domain");
        contentIdUnknown = contentRegistry.mint(ContentTypes.wrap(bytes32(uint256(1 << 99))), "name", "unknown-domain");
        contentRegistry.setApprovalForAll(operator, true);
        vm.stopPrank();
    }

    function test_deployInteractionContract_ContentDoesntExist() public {
        vm.expectRevert(ContentInteractionManager.ContentDoesntExist.selector);
        contentInteractionManager.deployInteractionContract(0);
    }

    function test_deployInteractionContract_CantHandleContentTypes() public {
        vm.expectRevert(ContentInteractionManager.CantHandleContentTypes.selector);
        contentInteractionManager.deployInteractionContract(contentIdDapp);

        vm.expectRevert(ContentInteractionManager.CantHandleContentTypes.selector);
        contentInteractionManager.deployInteractionContract(contentIdUnknown);
    }

    function test_deployInteractionContract_InteractionContractAlreadyDeployed() public {
        contentInteractionManager.deployInteractionContract(contentIdPress);
        assertNotEq(contentInteractionManager.getInteractionContract(contentIdPress), address(0));

        vm.expectRevert(ContentInteractionManager.InteractionContractAlreadyDeployed.selector);
        contentInteractionManager.deployInteractionContract(contentIdPress);
    }

    function test_deployInteractionContract() public {
        // Deploy the interaction contract
        contentInteractionManager.deployInteractionContract(contentIdPress);

        // Assert it's deployed
        assertNotEq(contentInteractionManager.getInteractionContract(contentIdPress), address(0));

        // Ensure the deployed contract match the interaction contract
        ContentInteraction interactionContract =
            ContentInteraction(contentInteractionManager.getInteractionContract(contentIdPress));
        assertEq(ContentTypes.unwrap(interactionContract.getContentType()), ContentTypes.unwrap(CONTENT_TYPE_PRESS));
    }

    function test_getInteractionContract() public {
        vm.expectRevert(ContentInteractionManager.NoInteractionContractFound.selector);
        contentInteractionManager.getInteractionContract(contentIdPress);

        contentInteractionManager.deployInteractionContract(contentIdPress);
        address deployedAddress = contentInteractionManager.getInteractionContract(contentIdPress);
        assertNotEq(deployedAddress, address(0));
    }

    /* -------------------------------------------------------------------------- */
    /*                          Campaign management test                          */
    /* -------------------------------------------------------------------------- */

    function test_attachCampaign() public {
        MockCampaign campaign1 = new MockCampaign(owner, address(contentInteractionManager));
        MockCampaign campaign2 = new MockCampaign(owner, address(contentInteractionManager));
        MockCampaign campaign3 = new MockCampaign(owner, address(contentInteractionManager));

        // Test role required
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.attachCampaign(contentIdPress, campaign1);

        // Test fail if interaction not present
        vm.expectRevert(ContentInteractionManager.NoInteractionContractFound.selector);
        vm.prank(operator);
        contentInteractionManager.attachCampaign(contentIdPress, campaign1);

        // Deploy interaction
        contentInteractionManager.deployInteractionContract(contentIdPress);
        ContentInteraction interactionContract =
            ContentInteraction(contentInteractionManager.getInteractionContract(contentIdPress));

        // Test op with interaction
        vm.prank(operator);
        contentInteractionManager.attachCampaign(contentIdPress, campaign1);
        assertEq(interactionContract.getCampaigns().length, 1);
        assertEq(address(interactionContract.getCampaigns()[0]), address(campaign1));

        // Test op with multiple campaign
        vm.startPrank(operator);
        contentInteractionManager.attachCampaign(contentIdPress, campaign2);
        contentInteractionManager.attachCampaign(contentIdPress, campaign3);
        vm.stopPrank();
        assertEq(interactionContract.getCampaigns().length, 3);
        assertEq(address(interactionContract.getCampaigns()[0]), address(campaign1));
        assertEq(address(interactionContract.getCampaigns()[1]), address(campaign2));
        assertEq(address(interactionContract.getCampaigns()[2]), address(campaign3));

        // Test can't repush an existing campaign
        vm.expectRevert(ContentInteraction.CampaignAlreadyPresent.selector);
        vm.prank(operator);
        contentInteractionManager.attachCampaign(contentIdPress, campaign1);

        // Ensure each campaign has the right roles from the interaction contract
        assertTrue(campaign1.hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE));
        assertTrue(campaign2.hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE));
        assertTrue(campaign3.hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE));
    }

    function test_detachCampaigns_single() public {
        MockCampaign campaign1 = new MockCampaign(owner, address(contentInteractionManager));
        MockCampaign campaign2 = new MockCampaign(owner, address(contentInteractionManager));

        // Deploy interaction and add campaign
        contentInteractionManager.deployInteractionContract(contentIdPress);
        ContentInteraction interactionContract =
            ContentInteraction(contentInteractionManager.getInteractionContract(contentIdPress));
        vm.prank(operator);
        contentInteractionManager.attachCampaign(contentIdPress, campaign1);

        InteractionCampaign[] memory toRemove = new InteractionCampaign[](1);
        toRemove[0] = campaign1;

        // Test role required
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.detachCampaigns(contentIdPress, toRemove);
        assertEq(interactionContract.getCampaigns().length, 1);
        assertEq(address(interactionContract.getCampaigns()[0]), address(campaign1));

        // Test not present campaign
        toRemove[0] = campaign2;
        vm.prank(operator);
        contentInteractionManager.detachCampaigns(contentIdPress, toRemove);
        assertEq(interactionContract.getCampaigns().length, 1);
        assertEq(address(interactionContract.getCampaigns()[0]), address(campaign1));

        // Test ok
        toRemove[0] = campaign1;
        vm.prank(operator);
        contentInteractionManager.detachCampaigns(contentIdPress, toRemove);

        assertEq(interactionContract.getCampaigns().length, 0);
        assertFalse(campaign1.hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE));
    }

    function test_detachCampaigns_multi() public {
        MockCampaign campaign1 = new MockCampaign(owner, address(contentInteractionManager));
        MockCampaign campaign2 = new MockCampaign(owner, address(contentInteractionManager));
        MockCampaign campaign3 = new MockCampaign(owner, address(contentInteractionManager));
        MockCampaign campaign4 = new MockCampaign(owner, address(contentInteractionManager));

        // Deploy interaction and add campaign
        contentInteractionManager.deployInteractionContract(contentIdPress);
        ContentInteraction interactionContract =
            ContentInteraction(contentInteractionManager.getInteractionContract(contentIdPress));
        vm.startPrank(operator);
        contentInteractionManager.attachCampaign(contentIdPress, campaign1);
        contentInteractionManager.attachCampaign(contentIdPress, campaign2);
        contentInteractionManager.attachCampaign(contentIdPress, campaign3);
        contentInteractionManager.attachCampaign(contentIdPress, campaign4);
        vm.stopPrank();

        InteractionCampaign[] memory toRemove = new InteractionCampaign[](1);
        toRemove[0] = campaign1;

        // Test ok with reordering
        toRemove[0] = campaign1;
        vm.prank(operator);
        contentInteractionManager.detachCampaigns(contentIdPress, toRemove);
        assertEq(interactionContract.getCampaigns().length, 3);
        assertEq(address(interactionContract.getCampaigns()[0]), address(campaign4));
        assertEq(address(interactionContract.getCampaigns()[1]), address(campaign2));
        assertEq(address(interactionContract.getCampaigns()[2]), address(campaign3));

        // Test remove all
        toRemove = new InteractionCampaign[](4);
        toRemove[0] = campaign1;
        toRemove[1] = campaign2;
        toRemove[2] = campaign3;
        toRemove[3] = campaign4;

        vm.prank(operator);
        contentInteractionManager.detachCampaigns(contentIdPress, toRemove);

        assertEq(interactionContract.getCampaigns().length, 0);
        assertFalse(campaign1.hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE));
        assertFalse(campaign2.hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE));
        assertFalse(campaign3.hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE));
        assertFalse(campaign4.hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE));
    }

    function test_walletLinked() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        vm.expectEmit(true, true, true, true);
        emit ContentInteractionManager.WalletLinked(alice, bob);

        vm.prank(alice);
        contentInteractionManager.walletLinked(bob);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Upgrade check                               */
    /* -------------------------------------------------------------------------- */

    function test_reinit() public {
        vm.expectRevert();
        contentInteractionManager.init(address(1));

        // Ensure we can't init raw instance
        ContentInteractionManager rawImplem = new ContentInteractionManager(contentRegistry, referralRegistry);
        vm.expectRevert();
        rawImplem.init(owner);
    }

    function test_upgrade() public {
        address newImplem = address(new ContentInteractionManager(contentRegistry, referralRegistry));

        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.upgradeToAndCall(newImplem, "");

        vm.prank(owner);
        contentInteractionManager.upgradeToAndCall(newImplem, "");
    }
}
