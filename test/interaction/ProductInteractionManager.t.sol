// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CampaignFactory} from "src/campaign/CampaignFactory.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {
    DENOMINATOR_DAPP,
    DENOMINATOR_PRESS,
    PRODUCT_TYPE_DAPP,
    PRODUCT_TYPE_PRESS,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {PRODUCT_MANAGER_ROLE, REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";

import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";

import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {Metadata, ProductRegistry} from "src/registry/ProductRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

contract ProductInteractionManagerTest is Test {
    address private owner = makeAddr("owner");
    address private operator = makeAddr("operator");

    ProductRegistry private productRegistry;
    ReferralRegistry private referralRegistry;
    ProductAdministratorRegistry private adminRegistry;
    InteractionFacetsFactory private facetFactory;
    CampaignFactory private campaignFactory;

    uint256 private productIdDapp;
    uint256 private productIdPress;
    uint256 private productIdMulti;
    uint256 private productIdUnknown;

    ProductInteractionManager private productInteractionManager;

    function setUp() public {
        productRegistry = new ProductRegistry(owner);
        referralRegistry = new ReferralRegistry(owner);
        adminRegistry = new ProductAdministratorRegistry(productRegistry);

        facetFactory = new InteractionFacetsFactory(referralRegistry, productRegistry, adminRegistry);
        campaignFactory = new CampaignFactory(referralRegistry, adminRegistry, owner);

        address implem = address(new ProductInteractionManager(productRegistry, referralRegistry, adminRegistry));
        address proxy = LibClone.deployERC1967(implem);
        productInteractionManager = ProductInteractionManager(proxy);
        productInteractionManager.init(owner, facetFactory, campaignFactory);

        // Grant the right roles to the product interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(address(productInteractionManager), REFERRAL_ALLOWANCE_MANAGER_ROLE);

        vm.startPrank(owner);
        productIdDapp = productRegistry.mint(PRODUCT_TYPE_DAPP, "name", "dapp-domain", owner);
        productIdPress = productRegistry.mint(PRODUCT_TYPE_PRESS, "name", "press-domain", owner);
        productIdMulti = productRegistry.mint(PRODUCT_TYPE_DAPP | PRODUCT_TYPE_PRESS, "name", "multi-domain", owner);
        productIdUnknown = productRegistry.mint(ProductTypes.wrap(uint256(1 << 99)), "name", "unknown-domain", owner);
        productRegistry.setApprovalForAll(operator, true);
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
        adminRegistry.grantRoles(productIdPress, testOperator, PRODUCT_MANAGER_ROLE);

        // Add it
        vm.prank(owner);
        adminRegistry.grantRoles(productIdPress, testOperator, PRODUCT_MANAGER_ROLE);

        assertTrue(adminRegistry.hasAllRolesOrAdmin(productIdPress, testOperator, PRODUCT_MANAGER_ROLE));

        // Ensure it can't add other operator
        vm.prank(testOperator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        adminRegistry.grantRoles(productIdPress, testOperator2, PRODUCT_MANAGER_ROLE);

        assertFalse(adminRegistry.hasAllRolesOrAdmin(productIdPress, testOperator2, PRODUCT_MANAGER_ROLE));

        // Ensure the operator can deploy stuff
        vm.prank(testOperator);
        productInteractionManager.deployInteractionContract(productIdPress);
        assertNotEq(address(productInteractionManager.getInteractionContract(productIdPress)), address(0));
    }

    function test_deleteOperator() public {
        address testOperator1 = makeAddr("testOperator");
        address testOperator2 = makeAddr("testOperator2");

        vm.startPrank(owner);
        adminRegistry.grantRoles(productIdPress, testOperator1, PRODUCT_MANAGER_ROLE);
        adminRegistry.grantRoles(productIdPress, testOperator2, PRODUCT_MANAGER_ROLE);
        vm.stopPrank();

        // Admin doing a remove
        vm.prank(owner);
        adminRegistry.revokeRoles(productIdPress, testOperator1, PRODUCT_MANAGER_ROLE);

        assertFalse(adminRegistry.hasAllRolesOrAdmin(productIdPress, testOperator1, PRODUCT_MANAGER_ROLE));

        // Self removing
        vm.prank(testOperator2);
        adminRegistry.renounceRoles(productIdPress, PRODUCT_MANAGER_ROLE);

        assertFalse(adminRegistry.hasAllRolesOrAdmin(productIdPress, testOperator2, PRODUCT_MANAGER_ROLE));
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction deployment                           */
    /* -------------------------------------------------------------------------- */

    function test_deployInteractionContract_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.deployInteractionContract(productIdDapp);
    }

    function test_deployInteractionContract_CantHandleProductTypes() public {
        vm.prank(operator);
        vm.expectRevert(ProductInteractionManager.CantHandleProductTypes.selector);
        productInteractionManager.deployInteractionContract(productIdUnknown);
    }

    function test_deployInteractionContract_InteractionContractAlreadyDeployed() public {
        vm.prank(operator);
        productInteractionManager.deployInteractionContract(productIdPress);
        assertNotEq(address(productInteractionManager.getInteractionContract(productIdPress)), address(0));

        vm.prank(operator);
        vm.expectRevert(ProductInteractionManager.InteractionContractAlreadyDeployed.selector);
        productInteractionManager.deployInteractionContract(productIdPress);
    }

    function test_deployInteractionContract() public {
        // Deploy the interaction contract
        vm.prank(operator);
        productInteractionManager.deployInteractionContract(productIdPress);

        // Assert it's deployed
        assertNotEq(address(productInteractionManager.getInteractionContract(productIdPress)), address(0));

        // Deploy the interaction contract for a product with multiple types
        vm.prank(operator);
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

        vm.prank(operator);
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
        vm.prank(operator);
        productInteractionManager.updateInteractionContract(productIdDapp);
    }

    function test_updateInteractionContract() public {
        vm.prank(operator);
        productInteractionManager.deployInteractionContract(productIdPress);
        vm.prank(operator);
        productInteractionManager.updateInteractionContract(productIdPress);
    }

    function test_deleteInteractionContract() public {
        vm.prank(operator);
        productInteractionManager.deployInteractionContract(productIdPress);

        ProductInteractionDiamond interactionContract =
            ProductInteractionDiamond(productInteractionManager.getInteractionContract(productIdPress));
        bytes32 tree = interactionContract.getReferralTree();
        assertTrue(referralRegistry.isAllowedOnTree(tree, address(interactionContract)));

        vm.prank(operator);
        productInteractionManager.deleteInteractionContract(productIdPress);

        assertFalse(referralRegistry.isAllowedOnTree(tree, address(interactionContract)));
        assertEq(address(interactionContract.getFacet(DENOMINATOR_PRESS)), address(0));

        vm.expectRevert(ProductInteractionManager.NoInteractionContractFound.selector);
        ProductInteractionDiamond(productInteractionManager.getInteractionContract(productIdPress));
    }

    function test_deleteInteractionContract_Unauthorized() public {
        vm.prank(operator);
        productInteractionManager.deployInteractionContract(productIdPress);

        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.deleteInteractionContract(productIdPress);
    }

    function test_updateFacetsFactory_Unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.updateFacetsFactory(facetFactory);
    }

    function test_updateFacetsFactory() public {
        vm.prank(owner);
        productInteractionManager.updateFacetsFactory(facetFactory);
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
            endDate: uint48(0),
            name: "test"
        });
        bytes memory initData = abi.encode(config);

        // Deploy interaction and add campaign
        vm.startPrank(operator);
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
        vm.prank(operator);
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

        vm.prank(operator);
        productInteractionManager.detachCampaigns(productIdPress, toRemove);

        assertEq(interactionContract.getCampaigns().length, 0);
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
            endDate: uint48(0),
            name: ""
        });
        bytes memory initData = abi.encode(config);

        // Deploy interaction
        vm.prank(operator);
        productInteractionManager.deployInteractionContract(productIdPress);
        ProductInteractionDiamond interactionContract =
            ProductInteractionDiamond(productInteractionManager.getInteractionContract(productIdPress));

        // Test role required
        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.deployCampaign(productIdPress, campaignId, initData);

        // Test ok
        vm.prank(operator);
        productInteractionManager.deployCampaign(productIdPress, campaignId, initData);

        assertEq(interactionContract.getCampaigns().length, 1);
    }

    function test_walletLinked() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        vm.expectEmit(true, true, true, true);
        emit ProductInteractionManager.WalletLinked(alice, bob);

        vm.prank(alice);
        productInteractionManager.walletLinked(bob);
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
        rawImplem.init(owner, facetFactory, campaignFactory);
    }

    function test_upgrade() public {
        address newImplem = address(new ProductInteractionManager(productRegistry, referralRegistry, adminRegistry));

        vm.expectRevert(Ownable.Unauthorized.selector);
        productInteractionManager.upgradeToAndCall(newImplem, "");

        vm.prank(owner);
        productInteractionManager.upgradeToAndCall(newImplem, "");
    }
}
