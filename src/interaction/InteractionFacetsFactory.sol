// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentTypes} from "../constants/ContentTypes.sol";
import {IFacetsFactory} from "../interfaces/IFacetsFactory.sol";
import {ContentRegistry} from "../registry/ContentRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {ContentInteractionDiamond} from "./ContentInteractionDiamond.sol";
import {DappInteractionFacet} from "./facets/DappInteractionFacet.sol";
import {IInteractionFacet} from "./facets/IInteractionFacet.sol";
import {PressInteractionFacet} from "./facets/PressInteractionFacet.sol";

/// @title InteractionFacetsFactory
/// @author @KONFeature
/// @notice Contract used to fetch the facets logics for the list of content types
/// @custom:security-contact contact@frak.id
contract InteractionFacetsFactory is IFacetsFactory {
    error CantHandleContentTypes();

    /// @dev The press facet address
    ReferralRegistry private immutable _REFERRAL_REGISTRY;
    ContentRegistry private immutable _CONTENT_REGISTRY;

    /// @dev The press facet address
    IInteractionFacet private immutable _PRESS_FACET;
    IInteractionFacet private immutable _DAPP_FACET;

    /// @dev Constructor, will deploy all the known facets
    constructor(ReferralRegistry _referralRegistry, ContentRegistry _contentRegistry) {
        // Save the registries
        _REFERRAL_REGISTRY = _referralRegistry;
        _CONTENT_REGISTRY = _contentRegistry;

        // Our facets
        _PRESS_FACET = new PressInteractionFacet(_referralRegistry);
        _DAPP_FACET = new DappInteractionFacet();
    }

    /* -------------------------------------------------------------------------- */
    /*                  Deploy a new content interaction diamond                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy a new content interaction diamond
    /// @dev Should only be called with delegate call, otherwise the manager would be the caller
    function createContentInteractionDiamond(uint256 _contentId, address _owner)
        public
        returns (ContentInteractionDiamond diamond)
    {
        // Retreive the owner of this content
        address contentOwner = _CONTENT_REGISTRY.ownerOf(_contentId);

        // Deploy the interaction contract
        diamond = new ContentInteractionDiamond(_contentId, _REFERRAL_REGISTRY, address(this), _owner, contentOwner);

        // Get the facets for it
        IInteractionFacet[] memory facets = getFacets(_CONTENT_REGISTRY.getContentTypes(_contentId));

        // If we have no facet logics, revert
        if (facets.length == 0) {
            revert CantHandleContentTypes();
        }

        // Set them
        diamond.setFacets(facets);
    }

    /* -------------------------------------------------------------------------- */
    /*           Get all the facets possible for the given content types          */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the facet for the given `contentTypes`
    function getFacets(ContentTypes contentTypes) public view returns (IInteractionFacet[] memory facets) {
        // Allocate 256 items for our initial array (max amount of content type possibles)
        facets = new IInteractionFacet[](256);
        uint256 index = 0;

        // Check if we have a press content type
        if (contentTypes.isPressType()) {
            facets[index] = _PRESS_FACET;
            index++;
        }
        if (contentTypes.isDappType()) {
            facets[index] = _DAPP_FACET;
            index++;
        }

        // TODO: dapp facet, to check when the stylus contract would be live, and adapt depending on it

        // Resize the array to the correct size
        assembly {
            mstore(facets, index)
        }
    }
}
