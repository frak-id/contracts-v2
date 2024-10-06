// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import "forge-std/Console.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CampaignBank} from "src/campaign/CampaignBank.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {
    ReferralCampaign, ReferralCampaignConfig, ReferralCampaignTriggerConfig
} from "src/campaign/ReferralCampaign.sol";
import {ReferralInteractions} from "src/constants/InteractionType.sol";
import {
    DENOMINATOR_DAPP,
    DENOMINATOR_PRESS,
    PRODUCT_TYPE_DAPP,
    PRODUCT_TYPE_PRESS,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {ProductRoles} from "src/registry/ProductAdministratorRegistry.sol";

contract ProductInteractionManagerTest is EcosystemAwareTest {
    uint256 private productIdDapp;
    uint256 private productIdPress;
    uint256 private productIdMulti;
    uint256 private productIdUnknown;

    /// @dev The bank we will use
    CampaignBank private campaignBank;

    function setUp() public {
        _initEcosystemAwareTest();

        productIdDapp = _mintProduct(PRODUCT_TYPE_DAPP, "name", "dapp-domain");
        productIdPress = _mintProduct(PRODUCT_TYPE_PRESS, "name", "press-domain");
        productIdMulti = _mintProduct(PRODUCT_TYPE_DAPP | PRODUCT_TYPE_PRESS, "name", "multi-domain");
        productIdUnknown = _mintProduct(ProductTypes.wrap(uint256(1 << 99)), "name", "unknown-domain");

        // Deploy a single bank
        // We don't rly need to productId here since every product has the same roles
        campaignBank = new CampaignBank(adminRegistry, productIdDapp, address(token));

        // Mint a few test tokens to the campaign
        token.mint(address(campaignBank), 1000 ether);

        // Start our bank
        vm.prank(productOwner);
        campaignBank.updateDistributionState(true);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Operator management                            */
    /* -------------------------------------------------------------------------- */

    function test_addInteractionMananger() public {
        address testOperator = makeAddr("testOperator");
        address testOperator2 = makeAddr("testOperator2");

        // Ensure only admin can do it
        vm.expectRevert(Ownable.Unauthorized.selector);
        adminRegistry.grantRoles(productIdPress, testOperator, ProductRoles.INTERACTION_MANAGER_ROLE);

        // Add it
        vm.prank(productOwner);
        adminRegistry.grantRoles(productIdPress, testOperator, ProductRoles.INTERACTION_MANAGER_ROLE);

        assertTrue(
            adminRegistry.hasAllRolesOrOwner(productIdPress, testOperator, ProductRoles.INTERACTION_MANAGER_ROLE)
        );

        // Ensure it can't add other operator
        vm.prank(testOperator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        adminRegistry.grantRoles(productIdPress, testOperator2, ProductRoles.INTERACTION_MANAGER_ROLE);

        assertFalse(
            adminRegistry.hasAllRolesOrOwner(productIdPress, testOperator2, ProductRoles.INTERACTION_MANAGER_ROLE)
        );

        // Ensure the operator can deploy stuff
        vm.prank(testOperator);
        productInteractionManager.deployInteractionContract(productIdPress);
        assertNotEq(address(productInteractionManager.getInteractionContract(productIdPress)), address(0));
    }

    function test_deleteInteractionManager() public {
        address testOperator1 = makeAddr("testOperator");
        address testOperator2 = makeAddr("testOperator2");

        vm.startPrank(productOwner);
        adminRegistry.grantRoles(productIdPress, testOperator1, ProductRoles.INTERACTION_MANAGER_ROLE);
        adminRegistry.grantRoles(productIdPress, testOperator2, ProductRoles.INTERACTION_MANAGER_ROLE);
        vm.stopPrank();

        // Admin doing a remove
        vm.prank(productOwner);
        adminRegistry.revokeRoles(productIdPress, testOperator1, ProductRoles.INTERACTION_MANAGER_ROLE);

        assertFalse(
            adminRegistry.hasAllRolesOrOwner(productIdPress, testOperator1, ProductRoles.INTERACTION_MANAGER_ROLE)
        );

        // Self removing
        vm.prank(testOperator2);
        adminRegistry.renounceRoles(productIdPress, ProductRoles.INTERACTION_MANAGER_ROLE);

        assertFalse(
            adminRegistry.hasAllRolesOrOwner(productIdPress, testOperator2, ProductRoles.INTERACTION_MANAGER_ROLE)
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction deployment                           */
    /* -------------------------------------------------------------------------- */

    function test_deployInteractionContract_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.deployInteractionContract(productIdDapp);
    }

    function test_deployInteractionContract_CantHandleProductTypes() public {
        vm.prank(productOwner);
        vm.expectRevert(ProductInteractionManager.CantHandleProductTypes.selector);
        productInteractionManager.deployInteractionContract(productIdUnknown);
    }

    function test_deployInteractionContract_InteractionContractAlreadyDeployed() public {
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);
        assertNotEq(address(productInteractionManager.getInteractionContract(productIdPress)), address(0));

        vm.prank(productOwner);
        vm.expectRevert(ProductInteractionManager.InteractionContractAlreadyDeployed.selector);
        productInteractionManager.deployInteractionContract(productIdPress);
    }

    function test_deployInteractionContract_SaltClash() public {
        // Deploy and delete the interaction contract
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);
        vm.prank(productOwner);
        productInteractionManager.deleteInteractionContract(productIdPress);

        // Try to redeploy it
        vm.prank(productOwner);
        vm.expectRevert();
        productInteractionManager.deployInteractionContract(productIdPress);

        // Try to redeploy it using another salt
        bytes32 _salt = keccak256(abi.encodePacked("salt"));
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress, _salt);
    }

    function test_deployInteractionContract() public {
        // Deploy the interaction contract
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);

        // Assert it's deployed
        assertNotEq(address(productInteractionManager.getInteractionContract(productIdPress)), address(0));

        // Deploy the interaction contract for a product with multiple types
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdMulti);
        ProductInteractionDiamond interaction = productInteractionManager.getInteractionContract(productIdMulti);
        assertNotEq(address(interaction), address(0));

        // Get the facet, and ensure it's not 0 for each product denomination
        assertNotEq(address(interaction.getFacet(DENOMINATOR_DAPP)), address(0));
        assertNotEq(address(interaction.getFacet(DENOMINATOR_PRESS)), address(0));
    }

    function test_getInteractionContract() public {
        vm.expectRevert(ProductInteractionManager.NoInteractionContractFound.selector);
        productInteractionManager.getInteractionContract(productIdPress);

        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);
        address deployedAddress = address(productInteractionManager.getInteractionContract(productIdPress));
        assertNotEq(deployedAddress, address(0));
    }

    function test_updateInteractionContract_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.updateInteractionContract(productIdDapp);
    }

    function test_updateInteractionContract_NoInteractionContractFound() public {
        vm.expectRevert(ProductInteractionManager.NoInteractionContractFound.selector);
        vm.prank(productOwner);
        productInteractionManager.updateInteractionContract(productIdDapp);
    }

    function test_updateInteractionContract() public {
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);
        vm.prank(productOwner);
        productInteractionManager.updateInteractionContract(productIdPress);
    }

    function test_deleteInteractionContract() public {
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);

        ProductInteractionDiamond interactionContract =
            ProductInteractionDiamond(productInteractionManager.getInteractionContract(productIdPress));
        bytes32 tree = interactionContract.getReferralTree();
        assertTrue(referralRegistry.isAllowedOnTree(tree, address(interactionContract)));

        vm.prank(productOwner);
        productInteractionManager.deleteInteractionContract(productIdPress);

        assertFalse(referralRegistry.isAllowedOnTree(tree, address(interactionContract)));
        assertEq(address(interactionContract.getFacet(DENOMINATOR_PRESS)), address(0));

        vm.expectRevert(ProductInteractionManager.NoInteractionContractFound.selector);
        ProductInteractionDiamond(productInteractionManager.getInteractionContract(productIdPress));
    }

    function test_deleteInteractionContract_Unauthorized() public {
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);

        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.deleteInteractionContract(productIdPress);
    }

    function test_updateFacetsFactory_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.updateFacetsFactory(facetFactory);
    }

    function test_updateFacetsFactory() public {
        vm.prank(contractOwner);
        productInteractionManager.updateFacetsFactory(facetFactory);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Campaign management test                          */
    /* -------------------------------------------------------------------------- */

    function test_detachCampaigns_multi() public {
        bytes4 campaignId = bytes4(keccak256("frak.campaign.referral"));
        bytes memory initData = _getReferralCampaignConfigInitData();

        // Deploy interaction and add campaign
        vm.startPrank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);
        ProductInteractionDiamond interactionContract =
            ProductInteractionDiamond(productInteractionManager.getInteractionContract(productIdPress));

        address campaign1 = productInteractionManager.deployCampaign(productIdPress, campaignId, initData);
        address campaign2 = productInteractionManager.deployCampaign(productIdPress, campaignId, initData);
        address campaign3 = productInteractionManager.deployCampaign(productIdPress, campaignId, initData);
        address campaign4 = productInteractionManager.deployCampaign(productIdPress, campaignId, initData);
        vm.stopPrank();

        InteractionCampaign[] memory toRemove = new InteractionCampaign[](1);
        toRemove[0] = InteractionCampaign(campaign1);

        // Test ok with reordering
        vm.prank(productOwner);
        productInteractionManager.detachCampaigns(productIdPress, toRemove);
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

        vm.prank(productOwner);
        productInteractionManager.detachCampaigns(productIdPress, toRemove);

        assertEq(interactionContract.getCampaigns().length, 0);
    }

    function test_deployCampaign() public {
        bytes4 campaignId = bytes4(keccak256("frak.campaign.referral"));
        bytes memory initData = _getReferralCampaignConfigInitData();

        // Deploy interaction
        vm.prank(productOwner);
        productInteractionManager.deployInteractionContract(productIdPress);
        ProductInteractionDiamond interactionContract =
            ProductInteractionDiamond(productInteractionManager.getInteractionContract(productIdPress));

        // Test role required
        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.deployCampaign(productIdPress, campaignId, initData);

        // Test ok
        vm.prank(productOwner);
        productInteractionManager.deployCampaign(productIdPress, campaignId, initData);

        assertEq(interactionContract.getCampaigns().length, 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Upgrade check                               */
    /* -------------------------------------------------------------------------- */

    function test_reinit() public {
        vm.expectRevert();
        productInteractionManager.init(address(1), facetFactory, campaignFactory);

        // Ensure we can't init raw instance
        ProductInteractionManager rawImplem =
            new ProductInteractionManager(productRegistry, referralRegistry, adminRegistry);
        vm.expectRevert();
        rawImplem.init(contractOwner, facetFactory, campaignFactory);
    }

    function test_upgrade() public {
        address newImplem = address(new ProductInteractionManager(productRegistry, referralRegistry, adminRegistry));

        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.upgradeToAndCall(newImplem, "");

        vm.prank(contractOwner);
        productInteractionManager.upgradeToAndCall(newImplem, "");
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function _getReferralCampaignConfigInitData() internal returns (bytes memory initData) {
        vm.pauseGasMetering();
        ReferralCampaignTriggerConfig[] memory triggers = new ReferralCampaignTriggerConfig[](1);
        triggers[0] = ReferralCampaignTriggerConfig({
            interactionType: ReferralInteractions.REFERRED,
            baseReward: 10 ether,
            userPercent: 5000, // 50%
            deperditionPerLevel: 8000, // 80%
            maxCountPerUser: 1
        });

        ReferralCampaignConfig memory config = ReferralCampaignConfig({
            name: "test",
            triggers: triggers,
            capConfig: ReferralCampaign.CapConfig({period: uint48(0), amount: uint208(0)}),
            activationPeriod: ReferralCampaign.ActivationPeriod({start: uint48(0), end: uint48(0)}),
            campaignBank: campaignBank
        });
        initData = abi.encode(config);
        vm.resumeGasMetering();
    }
}
