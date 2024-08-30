// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductTypes} from "../constants/ProductTypes.sol";
import {IFacetsFactory} from "../interfaces/IFacetsFactory.sol";

import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "../registry/ProductRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {ProductInteractionDiamond} from "./ProductInteractionDiamond.sol";
import {DappInteractionFacet} from "./facets/DappInteractionFacet.sol";
import {IInteractionFacet} from "./facets/IInteractionFacet.sol";
import {PressInteractionFacet} from "./facets/PressInteractionFacet.sol";
import {ReferralFeatureFacet} from "./facets/ReferralFeatureFacet.sol";

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

    /// @dev The facets addresses
    IInteractionFacet private immutable PRESS_FACET;
    IInteractionFacet private immutable DAPP_FACET;
    IInteractionFacet private immutable REFERRAL_FEATURE_FACET;

    /// @dev Constructor, will deploy all the known facets
    constructor(
        ReferralRegistry _referralRegistry,
        ProductRegistry _productRegistry,
        ProductAdministratorRegistry _productAdministratorRegistry
    ) {
        // Save the registries
        REFERRAL_REGISTRY = _referralRegistry;
        PRODUCT_REGISTRY = _productRegistry;
        PRODUCT_ADMINISTRATOR_REGISTRY = _productAdministratorRegistry;

        // Our facets
        PRESS_FACET = new PressInteractionFacet();
        DAPP_FACET = new DappInteractionFacet();
        REFERRAL_FEATURE_FACET = new ReferralFeatureFacet(_referralRegistry);
    }

    /* -------------------------------------------------------------------------- */
    /*                  Deploy a new product interaction diamond                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy a new product interaction diamond
    /// @dev Should only be called with delegate call, otherwise the manager would be the caller
    function createProductInteractionDiamond(uint256 _productId, address _owner)
        public
        returns (ProductInteractionDiamond diamond)
    {
        // Deploy the interaction contract
        diamond = new ProductInteractionDiamond(
            _productId, REFERRAL_REGISTRY, PRODUCT_ADMINISTRATOR_REGISTRY, address(this), _owner
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
        if (productTypes.hasReferralFeature()) {
            facets[index] = REFERRAL_FEATURE_FACET;
            index++;
        }

        // Resize the array to the correct size
        assembly {
            mstore(facets, index)
        }
    }
}
