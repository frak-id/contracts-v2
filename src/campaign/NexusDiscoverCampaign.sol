// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InvalidConfig} from "../constants/Errors.sol";
import {ReferralCampaignModule, CampaignConfig} from "../modules/ReferralCampaignModule.sol";

/// @author @KONFeature
/// @title NexusRegisterCampaign
/// @notice Contract used for a registration campagn
/// @custom:security-contact contact@frak.id
abstract contract NexusDiscoverCampaign is ReferralCampaignModule {

    // TODO: Should store the allowed tree
    // TODO: Role management to do that
    // TODO: Shouldn't use the hook to distribute the reward, should be a role gated function, to ensure no system abuse
    // TODO: Link with community token, ContentDiscover = has community token + referrer

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev The tree for new registration
    bytes32 private constant _REGISTRATION_TREE = keccak256("RegistrationReferralTree");

    /// @dev The initial reward for a registration
    uint256 private constant _REGISTRATION_INITIAL_REWARD = 25 ether;

    /// @dev The initial reward when a user discover a new content
    uint256 private constant _DISCOVER_CONTENT_INITIAL_REWARD = 10 ether;

    //// @dev Construction of our contract
    constructor(address _token)
        ReferralCampaignModule(
            CampaignConfig({
                /// @dev Max 5 level of MTC
                maxLevel: 5,
                /// @dev 50% decrease per level
                perLevelPercentage: 500,
                /// @dev The token used for the reward
                token: _token
            })
        )
    {
        if (_token == address(0)) {
            revert InvalidConfig();
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                       Hooks when a referral is added                       */
    /* -------------------------------------------------------------------------- */

    /// @dev hook when a user is referred by another user
    function onUserReferred(bytes32 _selector, address, address _referee) internal override {
        // If the selector is the registration tree
        if (_selector == _REGISTRATION_TREE) {
            // Distribute the rewards
            _distributeReferralRewards(_selector, _referee, true, _REGISTRATION_INITIAL_REWARD);
            return;
        }

        // Otherwise, it's a content discover
        _distributeReferralRewards(_selector, _referee, false, _DISCOVER_CONTENT_INITIAL_REWARD);
    }

    /* -------------------------------------------------------------------------- */
    /*                            External view methods                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the content discovery tree from a content id
    function getContentDiscoveryTree(uint256 contentId) external pure returns (bytes32) {
        return keccak256(abi.encodePacked("ContentDiscoveryTree", contentId));
    }
}
