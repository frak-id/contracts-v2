// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentTypes} from "../constants/ContentTypes.sol";
import {ContentRegistry} from "../registry/ContentRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";

import {IInteractionFacet} from "./facets/IInteractionFacet.sol";
import {PressInteractionFacet} from "./facets/PressInteractionFacet.sol";

/// @title InteractionFacetsFactory
/// @author @KONFeature
/// @notice Contract used to fetch the facets logics for the list of content types
/// @custom:security-contact contact@frak.id
contract InteractionFacetsFactory {
    /// @dev The press facet address
    IInteractionFacet private immutable _PRESS_FACET;

    /// @dev Constructor, will deploy all the known facets
    constructor(ReferralRegistry referralRegistry, ContentRegistry) {
        // Press facet
        _PRESS_FACET = new PressInteractionFacet(referralRegistry);
    }

    /* -------------------------------------------------------------------------- */
    /*          External view methods, get all facets for a content type          */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the facet for the given `contentTypes`
    function getFacets(ContentTypes contentTypes) external view returns (IInteractionFacet[] memory facets) {
        // Allocate 256 items for our initial array (max amount of content type possibles)
        facets = new IInteractionFacet[](256);
        uint256 index = 0;

        // Check if we have a press content type
        if (contentTypes.isPressType()) {
            facets[index] = _PRESS_FACET;
            index++;
        }

        // TODO: dapp facet, to check when the stylus contract would be live, and adapt depending on it

        // Resize the array to the correct size
        assembly {
            mstore(facets, index)
        }
    }
}
