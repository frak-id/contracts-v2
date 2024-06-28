// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentTypes} from "../constants/ContentTypes.sol";

import {ContentInteractionDiamond} from "../interaction/ContentInteractionDiamond.sol";
import {IInteractionFacet} from "../interaction/facets/IInteractionFacet.sol";

/// @author @KONFeature
/// @title IFacetsFactory
/// @notice Interface for facets factory
/// @custom:security-contact contact@frak.id
interface IFacetsFactory {
    /// @dev Deploy a new content interaction diamond
    /// @dev Should only be called with delegate call, otherwise the manager would be the caller
    function createContentInteractionDiamond(uint256 _contentId, address _owner)
        external
        returns (ContentInteractionDiamond diamond);

    /// @dev Get the facet for the given `contentTypes`
    function getFacets(ContentTypes contentTypes) external view returns (IInteractionFacet[] memory facets);
}
