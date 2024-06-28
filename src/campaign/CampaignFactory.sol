// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentInteractionManager} from "../interaction/ContentInteractionManager.sol";
import {ICampaignFactory} from "../interfaces/ICampaignFactory.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {ReferralCampaign} from "./ReferralCampaign.sol";

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

    bytes4 private constant REFERRAL_CAMPAIGN_IDENTIFIER = bytes4(keccak256("frak.campaign.referral"));

    /// @dev The referral registry
    ReferralRegistry internal immutable REFERRAL_REGISTRY;

    constructor(ReferralRegistry _referralRegistry) {
        REFERRAL_REGISTRY = _referralRegistry;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Deployment                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Entry point to create a new campaign
    function createCampaign(bytes4 _identifier, address _contentInteractionManager, bytes calldata _initData)
        public
        override
        returns (address)
    {
        address campaign;

        if (_identifier == REFERRAL_CAMPAIGN_IDENTIFIER) {
            campaign = _createReferralCampaign(_contentInteractionManager, _initData);
        } else {
            revert UnknownCampaignType(_identifier);
        }

        // Emit the event
        emit CampaignCreated(address(campaign));

        // And return the campaign
        return address(campaign);
    }

    /// @dev Create a new referral campaign
    function _createReferralCampaign(address _contentInteractionManager, bytes calldata _initData)
        internal
        returns (address)
    {
        // Parse the input data
        ReferralCampaign.CampaignConfig calldata config;
        assembly {
            config := _initData.offset
        }
        // Create the campaign
        ReferralCampaign campaign =
            new ReferralCampaign(config, REFERRAL_REGISTRY, msg.sender, _contentInteractionManager);
        return address(campaign);
    }
}
