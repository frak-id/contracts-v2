// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CampaignFactory} from "src/campaign/CampaignFactory.sol";
import {CAMPAIGN_EVENT_EMITTER_ROLE} from "src/campaign/InteractionCampaign.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {
    CONTENT_TYPE_DAPP,
    CONTENT_TYPE_PRESS,
    ContentTypes,
    DENOMINATOR_DAPP,
    DENOMINATOR_PRESS
} from "src/constants/ContentTypes.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ContentRegistry, Metadata} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

contract ContentInteractionManagerTest is Test {
    address private owner = makeAddr("owner");
    address private operator = makeAddr("operator");

    ContentRegistry private contentRegistry;
    ReferralRegistry private referralRegistry;
    InteractionFacetsFactory private facetFactory;
    CampaignFactory private campaignFactory;

    uint256 private contentIdDapp;
    uint256 private contentIdPress;
    uint256 private contentIdMulti;
    uint256 private contentIdUnknown;

    ContentInteractionManager private contentInteractionManager;

    function setUp() public {
        contentRegistry = new ContentRegistry(owner);
        referralRegistry = new ReferralRegistry(owner);

        facetFactory = new InteractionFacetsFactory(referralRegistry, contentRegistry);
        campaignFactory = new CampaignFactory(referralRegistry, owner);

        address implem = address(new ContentInteractionManager(contentRegistry, referralRegistry));
        address proxy = LibClone.deployERC1967(implem);
        contentInteractionManager = ContentInteractionManager(proxy);
        contentInteractionManager.init(owner, facetFactory, campaignFactory);

        // Grant the right roles to the content interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(address(contentInteractionManager), REFERRAL_ALLOWANCE_MANAGER_ROLE);

        vm.startPrank(owner);
        contentIdDapp = contentRegistry.mint(CONTENT_TYPE_DAPP, "name", "dapp-domain");
        contentIdPress = contentRegistry.mint(CONTENT_TYPE_PRESS, "name", "press-domain");
        contentIdMulti = contentRegistry.mint(CONTENT_TYPE_DAPP | CONTENT_TYPE_PRESS, "name", "multi-domain");
        contentIdUnknown = contentRegistry.mint(ContentTypes.wrap(uint256(1 << 99)), "name", "unknown-domain");
        contentRegistry.setApprovalForAll(operator, true);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                             Operator management                            */
    /* -------------------------------------------------------------------------- */

    function test_addOperator() public {
        address testOperator = makeAddr("testOperator");
        address testOperator2 = makeAddr("testOperator2");

        // Ensure only admin can do it
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.addOperator(contentIdPress, testOperator);

        // Add it
        vm.prank(owner);
        contentInteractionManager.addOperator(contentIdPress, testOperator);

        assertTrue(contentInteractionManager.isAllowedOnContent(contentIdPress, testOperator));

        // Ensure it can't add other operator
        vm.prank(testOperator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.addOperator(contentIdPress, testOperator2);

        assertFalse(contentInteractionManager.isAllowedOnContent(contentIdPress, testOperator2));

        // Ensure the operator can deploy stuff
        vm.prank(testOperator);
        contentInteractionManager.deployInteractionContract(contentIdPress);
        assertNotEq(address(contentInteractionManager.getInteractionContract(contentIdPress)), address(0));
    }

    function test_deleteOperator() public {
        address testOperator1 = makeAddr("testOperator");
        address testOperator2 = makeAddr("testOperator2");

        vm.startPrank(owner);
        contentInteractionManager.addOperator(contentIdPress, testOperator1);
        contentInteractionManager.addOperator(contentIdPress, testOperator2);
        vm.stopPrank();

        // Admin doing a remove
        vm.prank(owner);
        contentInteractionManager.deleteOperator(contentIdPress, testOperator1);

        assertFalse(contentInteractionManager.isAllowedOnContent(contentIdPress, testOperator1));

        // Self removing
        vm.prank(testOperator2);
        contentInteractionManager.deleteOperator(contentIdPress, testOperator2);

        assertFalse(contentInteractionManager.isAllowedOnContent(contentIdPress, testOperator2));
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction deployment                           */
    /* -------------------------------------------------------------------------- */

    function test_deployInteractionContract_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.deployInteractionContract(contentIdDapp);
    }

    function test_deployInteractionContract_CantHandleContentTypes() public {
        vm.prank(operator);
        vm.expectRevert(ContentInteractionManager.CantHandleContentTypes.selector);
        contentInteractionManager.deployInteractionContract(contentIdUnknown);
    }

    function test_deployInteractionContract_InteractionContractAlreadyDeployed() public {
        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentIdPress);
        assertNotEq(address(contentInteractionManager.getInteractionContract(contentIdPress)), address(0));

        vm.prank(operator);
        vm.expectRevert(ContentInteractionManager.InteractionContractAlreadyDeployed.selector);
        contentInteractionManager.deployInteractionContract(contentIdPress);
    }

    function test_deployInteractionContract() public {
        // Deploy the interaction contract
        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentIdPress);

        // Assert it's deployed
        assertNotEq(address(contentInteractionManager.getInteractionContract(contentIdPress)), address(0));

        // Deploy the interaction contract for a content with multiple types
        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentIdMulti);
        ContentInteractionDiamond interaction = contentInteractionManager.getInteractionContract(contentIdMulti);
        assertNotEq(address(interaction), address(0));

        // Get the facet, and ensure it's not 0 for each content denomination
        assertNotEq(address(interaction.getFacet(DENOMINATOR_DAPP)), address(0));
        assertNotEq(address(interaction.getFacet(DENOMINATOR_PRESS)), address(0));
    }

    function test_getInteractionContract() public {
        vm.expectRevert(ContentInteractionManager.NoInteractionContractFound.selector);
        contentInteractionManager.getInteractionContract(contentIdPress);

        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentIdPress);
        address deployedAddress = address(contentInteractionManager.getInteractionContract(contentIdPress));
        assertNotEq(deployedAddress, address(0));
    }

    function test_updateInteractionContract_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.updateInteractionContract(contentIdDapp);
    }

    function test_updateInteractionContract_NoInteractionContractFound() public {
        vm.expectRevert(ContentInteractionManager.NoInteractionContractFound.selector);
        vm.prank(operator);
        contentInteractionManager.updateInteractionContract(contentIdDapp);
    }

    function test_updateInteractionContract() public {
        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentIdPress);
        vm.prank(operator);
        contentInteractionManager.updateInteractionContract(contentIdPress);
    }

    function test_deleteInteractionContract() public {
        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentIdPress);

        ContentInteractionDiamond interactionContract =
            ContentInteractionDiamond(contentInteractionManager.getInteractionContract(contentIdPress));
        bytes32 tree = interactionContract.getReferralTree();
        assertTrue(referralRegistry.isAllowedOnTree(tree, address(interactionContract)));

        vm.prank(operator);
        contentInteractionManager.deleteInteractionContract(contentIdPress);

        assertFalse(referralRegistry.isAllowedOnTree(tree, address(interactionContract)));
        assertEq(address(interactionContract.getFacet(DENOMINATOR_PRESS)), address(0));

        vm.expectRevert(ContentInteractionManager.NoInteractionContractFound.selector);
        ContentInteractionDiamond(contentInteractionManager.getInteractionContract(contentIdPress));
    }

    function test_deleteInteractionContract_Unauthorized() public {
        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentIdPress);

        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.deleteInteractionContract(contentIdPress);
    }

    function test_updateFacetsFactory_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.updateFacetsFactory(facetFactory);
    }

    function test_updateFacetsFactory() public {
        vm.prank(owner);
        contentInteractionManager.updateFacetsFactory(facetFactory);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Campaign management test                          */
    /* -------------------------------------------------------------------------- */

    function test_detachCampaigns_multi() public {
        bytes4 campaignId = bytes4(keccak256("frak.campaign.referral"));
        ReferralCampaign.CampaignConfig memory config = ReferralCampaign.CampaignConfig({
            token: makeAddr("testToken"),
            initialReward: 10 ether,
            userRewardPercent: 5_000, // 50%
            distributionCapPeriod: 1 days,
            distributionCap: 100 ether,
            startDate: uint48(0),
            endDate: uint48(0)
        });
        bytes memory initData = abi.encode(config);

        // Deploy interaction and add campaign
        vm.startPrank(operator);
        contentInteractionManager.deployInteractionContract(contentIdPress);
        ContentInteractionDiamond interactionContract =
            ContentInteractionDiamond(contentInteractionManager.getInteractionContract(contentIdPress));

        address campaign1 = contentInteractionManager.deployCampaign(contentIdPress, campaignId, initData);
        address campaign2 = contentInteractionManager.deployCampaign(contentIdPress, campaignId, initData);
        address campaign3 = contentInteractionManager.deployCampaign(contentIdPress, campaignId, initData);
        address campaign4 = contentInteractionManager.deployCampaign(contentIdPress, campaignId, initData);
        vm.stopPrank();

        InteractionCampaign[] memory toRemove = new InteractionCampaign[](1);
        toRemove[0] = InteractionCampaign(campaign1);

        // Test ok with reordering
        vm.prank(operator);
        contentInteractionManager.detachCampaigns(contentIdPress, toRemove);
        assertEq(interactionContract.getCampaigns().length, 3);
        assertEq(address(interactionContract.getCampaigns()[0]), campaign4);
        assertEq(address(interactionContract.getCampaigns()[1]), campaign2);
        assertEq(address(interactionContract.getCampaigns()[2]), campaign3);

        // Test remove all
        toRemove = new InteractionCampaign[](4);
        toRemove[0] = InteractionCampaign(campaign1);
        toRemove[1] = InteractionCampaign(campaign2);
        toRemove[2] = InteractionCampaign(campaign3);
        toRemove[3] = InteractionCampaign(campaign4);

        vm.prank(operator);
        contentInteractionManager.detachCampaigns(contentIdPress, toRemove);

        assertEq(interactionContract.getCampaigns().length, 0);
        assertFalse(
            InteractionCampaign(campaign1).hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE)
        );
        assertFalse(
            InteractionCampaign(campaign2).hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE)
        );
        assertFalse(
            InteractionCampaign(campaign3).hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE)
        );
        assertFalse(
            InteractionCampaign(campaign4).hasAllRoles(address(interactionContract), CAMPAIGN_EVENT_EMITTER_ROLE)
        );
    }

    function test_deployCampaign() public {
        bytes4 campaignId = bytes4(keccak256("frak.campaign.referral"));
        ReferralCampaign.CampaignConfig memory config = ReferralCampaign.CampaignConfig({
            token: makeAddr("testToken"),
            initialReward: 10 ether,
            userRewardPercent: 5_000, // 50%
            distributionCapPeriod: 1 days,
            distributionCap: 100 ether,
            startDate: uint48(0),
            endDate: uint48(0)
        });
        bytes memory initData = abi.encode(config);

        // Deploy interaction
        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentIdPress);
        ContentInteractionDiamond interactionContract =
            ContentInteractionDiamond(contentInteractionManager.getInteractionContract(contentIdPress));

        // Test role required
        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.deployCampaign(contentIdPress, campaignId, initData);

        // Test ok
        vm.prank(operator);
        contentInteractionManager.deployCampaign(contentIdPress, campaignId, initData);

        assertEq(interactionContract.getCampaigns().length, 1);
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
        contentInteractionManager.init(address(1), facetFactory, campaignFactory);

        // Ensure we can't init raw instance
        ContentInteractionManager rawImplem = new ContentInteractionManager(contentRegistry, referralRegistry);
        vm.expectRevert();
        rawImplem.init(owner, facetFactory, campaignFactory);
    }

    function test_upgrade() public {
        address newImplem = address(new ContentInteractionManager(contentRegistry, referralRegistry));

        vm.expectRevert(Ownable.Unauthorized.selector);
        contentInteractionManager.upgradeToAndCall(newImplem, "");

        vm.prank(owner);
        contentInteractionManager.upgradeToAndCall(newImplem, "");
    }
}
