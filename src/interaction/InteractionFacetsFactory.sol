// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductTypes} from "../constants/ProductTypes.sol";
import {IFacetsFactory} from "../interfaces/IFacetsFactory.sol";
import {IPurchaseOracle} from "../oracle/IPurchaseOracle.sol";
import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "../registry/ProductRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {ProductInteractionDiamond} from "./ProductInteractionDiamond.sol";
import {DappInteractionFacet} from "./facets/DappInteractionFacet.sol";
import {IInteractionFacet} from "./facets/IInteractionFacet.sol";
import {PressInteractionFacet} from "./facets/PressInteractionFacet.sol";
import {PurchaseFeatureFacet} from "./facets/PurchaseFeatureFacet.sol";
import {ReferralFeatureFacet} from "./facets/ReferralFeatureFacet.sol";
import {WebShopInteractionFacet} from "./facets/WebShopInteractionFacet.sol";

/// @title InteractionFacetsFactory
/// @author @KONFeature
/// @notice Contract used to fetch the facets logics for the list of product types
/// @custom:security-contact contact@frak.id
contract InteractionFacetsFactory is IFacetsFactory {
    error CantHandleProductTypes();

    /// @dev The different registries
    ReferralRegistry private immutable REFERRAL_REGISTRY;
    ProductRegistry private immutable PRODUCT_REGISTRY;
    ProductAdministratorRegistry internal immutable PRODUCT_ADMINISTRATOR_REGISTRY;

    /// @dev The purchase oracle
    IPurchaseOracle internal immutable PURCHASE_ORACLE;

    /// @dev The core facets addresses
    IInteractionFacet private immutable PRESS_FACET;
    IInteractionFacet private immutable DAPP_FACET;
    IInteractionFacet private immutable WEB_SHOP_FACET;

    /// @dev The feature facets addresses
    IInteractionFacet private immutable REFERRAL_FEATURE_FACET;
    IInteractionFacet private immutable PURCHASE_FEATURE_FACET;

    /// @dev Constructor, will deploy all the known facets
    constructor(
        ReferralRegistry _referralRegistry,
        ProductRegistry _productRegistry,
        ProductAdministratorRegistry _productAdministratorRegistry,
        IPurchaseOracle _purchaseOracle
    ) {
        // Save the registries
        REFERRAL_REGISTRY = _referralRegistry;
        PRODUCT_REGISTRY = _productRegistry;
        PRODUCT_ADMINISTRATOR_REGISTRY = _productAdministratorRegistry;

        // Deploy the facets we will link
        PRESS_FACET = new PressInteractionFacet();
        DAPP_FACET = new DappInteractionFacet();
        WEB_SHOP_FACET = new WebShopInteractionFacet();

        REFERRAL_FEATURE_FACET = new ReferralFeatureFacet(_referralRegistry);
        PURCHASE_FEATURE_FACET = new PurchaseFeatureFacet(_purchaseOracle);
    }

    /* -------------------------------------------------------------------------- */
    /*                  Deploy a new product interaction diamond                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy a new product interaction diamond
    /// @dev Should only be called with delegate call, otherwise the manager would be the caller
    function createProductInteractionDiamond(uint256 _productId, bytes32 _salt)
        public
        returns (ProductInteractionDiamond diamond)
    {
        // Mix product id and salt for a more unique diamond
        _salt = keccak256(abi.encodePacked(_productId, _salt));

        // Deploy the interaction contract
        diamond = new ProductInteractionDiamond{salt: _salt}(
            _productId, REFERRAL_REGISTRY, PRODUCT_ADMINISTRATOR_REGISTRY, address(this)
        );

        // Get the facets for it
        IInteractionFacet[] memory facets = getFacets(PRODUCT_REGISTRY.getProductTypes(_productId));

        // If we have no facet logics, revert
        if (facets.length == 0) {
            revert CantHandleProductTypes();
        }

        // Set them
        diamond.setFacets(facets);
    }

    /* -------------------------------------------------------------------------- */
    /*           Get all the facets possible for the given product types          */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the facet for the given `productTypes`
    function getFacets(ProductTypes productTypes) public view returns (IInteractionFacet[] memory facets) {
        // Allocate 256 items for our initial array (max amount of product type possibles)
        facets = new IInteractionFacet[](256);
        uint256 index = 0;

        // Check if we have a press product type
        if (productTypes.isPressType()) {
            facets[index] = PRESS_FACET;
            index++;
        }
        if (productTypes.isDappType()) {
            facets[index] = DAPP_FACET;
            index++;
        }
        if (productTypes.isWebShopType()) {
            facets[index] = WEB_SHOP_FACET;
            index++;
        }

        if (productTypes.hasReferralFeature()) {
            facets[index] = REFERRAL_FEATURE_FACET;
            index++;
        }
        if (productTypes.hasPurchaseFeature()) {
            facets[index] = PURCHASE_FEATURE_FACET;
            index++;
        }

        // Resize the array to the correct size
        assembly {
            mstore(facets, index)
        }
    }
}
