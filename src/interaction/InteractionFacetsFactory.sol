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
import {ReferralFeatureFacet} from "./facets/ReferralFeatureFacet.sol";

/// @title InteractionFacetsFactory
/// @author @KONFeature
/// @notice Contract used to fetch the facets logics for the list of content types
/// @custom:security-contact contact@frak.id
contract InteractionFacetsFactory is IFacetsFactory {
    error CantHandleContentTypes();

    /// @dev The press facet address
    ReferralRegistry private immutable REFERRAL_REGISTRY;
    ContentRegistry private immutable CONTENT_REGISTRY;

    /// @dev The facets addresses
    IInteractionFacet private immutable PRESS_FACET;
    IInteractionFacet private immutable DAPP_FACET;
    IInteractionFacet private immutable REFERRAL_FEATURE_FACET;

    /// @dev Constructor, will deploy all the known facets
    constructor(ReferralRegistry _referralRegistry, ContentRegistry _contentRegistry) {
        // Save the registries
        REFERRAL_REGISTRY = _referralRegistry;
        CONTENT_REGISTRY = _contentRegistry;

        // Our facets
        PRESS_FACET = new PressInteractionFacet();
        DAPP_FACET = new DappInteractionFacet();
        REFERRAL_FEATURE_FACET = new ReferralFeatureFacet(_referralRegistry);
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
        address contentOwner = CONTENT_REGISTRY.ownerOf(_contentId);

        // Deploy the interaction contract
        diamond = new ContentInteractionDiamond(_contentId, REFERRAL_REGISTRY, address(this), _owner, contentOwner);

        // Get the facets for it
        IInteractionFacet[] memory facets = getFacets(CONTENT_REGISTRY.getContentTypes(_contentId));

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
            facets[index] = PRESS_FACET;
            index++;
        }
        if (contentTypes.isDappType()) {
            facets[index] = DAPP_FACET;
            index++;
        }
        if (contentTypes.hasReferralFeature()) {
            facets[index] = REFERRAL_FEATURE_FACET;
            index++;
        }

        // Resize the array to the correct size
        assembly {
            mstore(facets, index)
        }
    }
}
