// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "./utils/MockErc20.sol";
import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CampaignFactory} from "src/campaign/CampaignFactory.sol";
import {ProductTypes} from "src/constants/ProductTypes.sol";
import {CAMPAIGN_MANAGER_ROLE, PRODUCT_MANAGER_ROLE} from "src/constants/Roles.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {PurchaseOracle} from "src/oracle/PurchaseOracle.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE, ReferralRegistry} from "src/registry/ReferralRegistry.sol";

/// @dev Test with all the frak ecosystem context
abstract contract EcosystemAwareTest is Test {
    // Setup a few wallet that could be used almost everywhere
    address internal owner = makeAddr("owner");
    address internal productOwner = makeAddr("productOwner");
    address internal productManager = makeAddr("productManager");
    address internal campaignManager = makeAddr("campaignManager");
    address internal frakCampaignWallet = makeAddr("frakCampaignWallet");

    /// @dev A mocked erc20 token
    MockErc20 internal token = new MockErc20();

    /// @dev The different regitries
    ProductRegistry internal productRegistry = new ProductRegistry(owner);
    ReferralRegistry internal referralRegistry = new ReferralRegistry(owner);
    ProductAdministratorRegistry internal adminRegistry = new ProductAdministratorRegistry(productRegistry);

    /// @dev The purchase oracle
    PurchaseOracle internal purchaseOracle = new PurchaseOracle();

    /// @dev The different factories
    InteractionFacetsFactory internal facetFactory =
        new InteractionFacetsFactory(referralRegistry, productRegistry, adminRegistry, purchaseOracle);
    CampaignFactory internal campaignFactory = new CampaignFactory(referralRegistry, adminRegistry, frakCampaignWallet);

    /// @dev The product interaction manager
    ProductInteractionManager internal productInteractionManager;

    function _initEcosystemAwareTest() internal {
        // Create our product interaction manager
        address implem = address(new ProductInteractionManager(productRegistry, referralRegistry, adminRegistry));
        address proxy = LibClone.deployERC1967(implem);
        productInteractionManager = ProductInteractionManager(proxy);
        productInteractionManager.init(owner, facetFactory, campaignFactory);

        // Label a few stuff
        vm.label(implem, "ProductInteractionManager-Implementation");
        vm.label(proxy, "ProductInteractionManager-Proxy");

        // Grant the right roles to the product interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(address(productInteractionManager), REFERRAL_ALLOWANCE_MANAGER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Test to ensure proper setup                        */
    /* -------------------------------------------------------------------------- */
    function test_ecosystemSetup() public view {
        // Ensure everything is deployed
        assertNotEq(address(productRegistry), address(0));
        assertNotEq(address(referralRegistry), address(0));
        assertNotEq(address(adminRegistry), address(0));
        assertNotEq(address(purchaseOracle), address(0));
        assertNotEq(address(facetFactory), address(0));
        assertNotEq(address(campaignFactory), address(0));
        assertNotEq(address(productInteractionManager), address(0));

        // Ensore role is granted as needed
        assertTrue(referralRegistry.hasAllRoles(address(productInteractionManager), REFERRAL_ALLOWANCE_MANAGER_ROLE));
    }

    /* -------------------------------------------------------------------------- */
    /*                                Some helpers                                */
    /* -------------------------------------------------------------------------- */

    function _mintProduct(ProductTypes _productTypes, string memory _name, string memory _domain)
        internal
        returns (uint256 productId)
    {
        // Mint the product
        vm.prank(owner);
        productId = productRegistry.mint(_productTypes, _name, _domain, productOwner);

        // Grant the right roles to the product interaction manager
        vm.startPrank(productOwner);
        adminRegistry.grantRoles(productId, productManager, PRODUCT_MANAGER_ROLE);
        adminRegistry.grantRoles(productId, campaignManager, CAMPAIGN_MANAGER_ROLE);
        vm.stopPrank();
    }

    function _mintProductWithInteraction(ProductTypes _productTypes, string memory _name, string memory _domain)
        internal
        returns (uint256 productId, ProductInteractionDiamond productInteraction)
    {
        // Mint the product
        productId = _mintProduct(_productTypes, _name, _domain);

        // Deploy the interaction contract
        vm.prank(productManager);
        productInteraction = productInteractionManager.deployInteractionContract(productId);

        // Label the interaction contract
        vm.label(address(productInteraction), string.concat("InteractionDiamond-", _name));
    }
}
