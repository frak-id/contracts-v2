// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductInteractionDiamond} from "../interaction/ProductInteractionDiamond.sol";
import {ICampaignFactory} from "../interfaces/ICampaignFactory.sol";
import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {AffiliationFixedCampaign, AffiliationFixedCampaignConfig} from "./AffiliationFixedCampaign.sol";
import {AffiliationRangeCampaign, AffiliationRangeCampaignConfig} from "./AffiliationRangeCampaign.sol";

/// @author @KONFeature
/// @title CampaignFactory
/// @notice Smart contract used to deploy campaign
/// @custom:security-contact contact@frak.id
contract CampaignFactory is ICampaignFactory {
    /* -------------------------------------------------------------------------- */
    /*                                    Error                                   */
    /* -------------------------------------------------------------------------- */

    error UnknownCampaignType(bytes4 identifier);

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event CampaignCreated(address campaign);

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev `bytes4(keccak256("frak.campaign.affiliation-fixed"))`
    bytes4 private constant AFFILIATION_FIXED_CAMPAIGN_IDENTIFIER = 0x26def63c;

    /// @dev `bytes4(keccak256("frak.campaign.affiliation-range"))`
    bytes4 private constant AFFILIATION_RANGE_CAMPAIGN_IDENTIFIER = 0xf1a57c61;

    /// @dev The referral registry
    ReferralRegistry private immutable REFERRAL_REGISTRY;

    /// @dev The referral registry
    ProductAdministratorRegistry private immutable PRODUCT_ADMINISTRATOR_REGISTRY;

    constructor(ReferralRegistry _referralRegistry, ProductAdministratorRegistry _productAdministratorRegistry) {
        REFERRAL_REGISTRY = _referralRegistry;
        PRODUCT_ADMINISTRATOR_REGISTRY = _productAdministratorRegistry;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Deployment                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Entry point to create a new campaign
    function createCampaign(ProductInteractionDiamond _interaction, bytes4 _identifier, bytes calldata _initData)
        public
        override
        returns (address)
    {
        address campaign;

        if (_identifier == AFFILIATION_FIXED_CAMPAIGN_IDENTIFIER) {
            campaign = _createAffiliationFixedCampaign(_interaction, _initData);
        } else if (_identifier == AFFILIATION_RANGE_CAMPAIGN_IDENTIFIER) {
            campaign = _createAffiliationRangeCampaign(_interaction, _initData);
        } else {
            revert UnknownCampaignType(_identifier);
        }

        // Emit the event
        emit CampaignCreated(address(campaign));

        // And return the campaign
        return address(campaign);
    }

    /// @dev Create a new fixed affiliation campaign
    function _createAffiliationFixedCampaign(ProductInteractionDiamond _interaction, bytes calldata _initData)
        internal
        returns (address)
    {
        // Parse the input data
        AffiliationFixedCampaignConfig memory config = abi.decode(_initData, (AffiliationFixedCampaignConfig));

        // Create the campaign
        AffiliationFixedCampaign campaign =
            new AffiliationFixedCampaign(config, REFERRAL_REGISTRY, PRODUCT_ADMINISTRATOR_REGISTRY, _interaction);
        return address(campaign);
    }

    /// @dev Create a new range affiliation campaign
    function _createAffiliationRangeCampaign(ProductInteractionDiamond _interaction, bytes calldata _initData)
        internal
        returns (address)
    {
        // Parse the input data
        AffiliationRangeCampaignConfig memory config = abi.decode(_initData, (AffiliationRangeCampaignConfig));

        // Create the campaign
        AffiliationRangeCampaign campaign =
            new AffiliationRangeCampaign(config, REFERRAL_REGISTRY, PRODUCT_ADMINISTRATOR_REGISTRY, _interaction);
        return address(campaign);
    }
}
