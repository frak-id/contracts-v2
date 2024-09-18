// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, ReferralInteractions} from "../constants/InteractionType.sol";
import {ProductTypes} from "../constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "../interaction/ProductInteractionDiamond.sol";
import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {InteractionCampaign} from "./InteractionCampaign.sol";

/// @author @KONFeature
/// @title ReferredPurchaseCampaign
/// @notice Smart contract for a referral purchase compagn
/// @custom:security-contact contact@frak.id
contract ReferredPurchaseCampaign is InteractionCampaign {
    using InteractionTypeLib for bytes;
    using ReferralInteractions for bytes;

    struct CampaignConfig {
        // Optional name for the campaign (as bytes32)
        bytes32 name;
    }

    constructor(
        CampaignConfig memory _config,
        ProductAdministratorRegistry _productAdministratorRegistry,
        ProductInteractionDiamond _interaction
    ) InteractionCampaign(_productAdministratorRegistry, _interaction, _config.name) {}

    /* -------------------------------------------------------------------------- */
    /*                               Campaign status                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the campaign metadata
    function getMetadata() public view override returns (string memory _type, string memory version, bytes32 name) {
        _type = "frak.campaign.pruchase_referral";
        version = "0.0.1";
        name = _interactionCampaignStorage().name;
    }

    /// @dev Check if the campaign is active or not
    function isActive() public view override returns (bool) {
        return true;
    }

    /// @dev Check if the given campaign support the `_productType`
    function supportProductType(ProductTypes _productType) public pure override returns (bool) {
        // Only supporting press product
        return _productType.hasPurchaseFeature() && _productType.hasReferralFeature();
    }

    /* -------------------------------------------------------------------------- */
    /*                         Campaign distribution logic                        */
    /* -------------------------------------------------------------------------- */

    /// @dev Handle the given interaction
    function innerHandleInteraction(bytes calldata _data) internal override {}
}
