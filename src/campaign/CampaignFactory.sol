// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentInteractionDiamond} from "../interaction/ContentInteractionDiamond.sol";
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

    /// @dev `bytes4(keccak256("frak.campaign.referral"))`
    bytes4 private constant REFERRAL_CAMPAIGN_IDENTIFIER = 0x1a8750ce;

    /// @dev The referral registry
    ReferralRegistry private immutable REFERRAL_REGISTRY;

    /// @dev The frak campaign wallet
    address private immutable FRAK_CAMPAIGN_WALLET;

    constructor(ReferralRegistry _referralRegistry, address _frakCampaignWallet) {
        REFERRAL_REGISTRY = _referralRegistry;
        FRAK_CAMPAIGN_WALLET = _frakCampaignWallet;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Deployment                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Entry point to create a new campaign
    function createCampaign(
        ContentInteractionDiamond _interaction,
        address _owner,
        bytes4 _identifier,
        bytes calldata _initData
    ) public override returns (address) {
        address campaign;

        if (_identifier == REFERRAL_CAMPAIGN_IDENTIFIER) {
            campaign = _createReferralCampaign(_interaction, _owner, _initData);
        } else {
            revert UnknownCampaignType(_identifier);
        }

        // Emit the event
        emit CampaignCreated(address(campaign));

        // And return the campaign
        return address(campaign);
    }

    /// @dev Create a new referral campaign
    function _createReferralCampaign(ContentInteractionDiamond _interaction, address _owner, bytes calldata _initData)
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
            new ReferralCampaign(config, REFERRAL_REGISTRY, _owner, FRAK_CAMPAIGN_WALLET, _interaction);
        return address(campaign);
    }
}
