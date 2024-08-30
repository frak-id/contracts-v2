// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductTypes} from "../constants/ProductTypes.sol";

import {ProductInteractionDiamond} from "../interaction/ProductInteractionDiamond.sol";
import {IInteractionFacet} from "../interaction/facets/IInteractionFacet.sol";

/// @author @KONFeature
/// @title IFacetsFactory
/// @notice Interface for facets factory
/// @custom:security-contact contact@frak.id
interface IFacetsFactory {
    /// @dev Deploy a new content interaction diamond
    /// @dev Should only be called with delegate call, otherwise the manager would be the caller
    function createProductInteractionDiamond(uint256 _productId, address _owner)
        external
        returns (ProductInteractionDiamond diamond);

    /// @dev Get the facet for the given `productTypes`
    function getFacets(ProductTypes productTypes) external view returns (IInteractionFacet[] memory facets);
}
