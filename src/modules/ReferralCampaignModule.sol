// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InvalidConfig} from "../constants/Errors.sol";
import {ReferralModule} from "./ReferralModule.sol";
import {PushPullModule} from "./PushPullModule.sol";

/// @dev Config struct for a referral campaign
struct CampaignConfig {
    /// @dev The maximum level where we will perform Multi Tier Comission (MTC)
    uint256 maxLevel;
    /// @dev The percentage of the comission for each level (on 1/10_000 scale, so 5% = 500, 0.5% = 50, etc.),
    ///     level 1 = 100%, level 2 = perLevelPercentage * 100%, level 3 = level 2 * perLevelPercentage, etc.
    uint256 perLevelPercentage;
    /// @dev The address of the token used for the reward
    address token;
}

/// @author @KONFeature
/// @title ReferralCampaignModule
/// @notice Contract providing utilities to distribute rewards for a referral campaign
/// @custom:security-contact contact@frak.id
abstract contract ReferralCampaignModule is ReferralModule, PushPullModule {
    /// @dev The maximum level where we will perform Multi Tier Comission (MTC)
    uint256 private immutable _maxLevel;

    /// @dev The percentage of the comission for each level (on 1/10_000 scale, so 5% = 500, 0.5% = 50, etc.),
    ///     level 1 = 100%, level 2 = perLevelPercentage * 100%, level 3 = level 2 * perLevelPercentage, etc.
    uint256 private immutable _perLevelPercentage;

    /// @dev The token used for the reward
    address private immutable _token;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when the campaign is inactive
    error InactiveCampaign();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.module.referral-campaign')) - 1)
    bytes32 private constant _REFERRAL_CAMPAIGN_MODULE_STORAGE_SLOT =
        0xca6fd11cdb4af68f0193ebfd72648afff0f9e9d406f3663d47d3a3a498d4406e;

    struct ReferralCampaignModuleStorage {
        /// @dev Is the current referral campaign acitve?
        bool isActive;
    }

    function _referralCampaignStorage() private pure returns (ReferralCampaignModuleStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _REFERRAL_CAMPAIGN_MODULE_STORAGE_SLOT
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Constructor, set all our immutable fields
    constructor(CampaignConfig memory config) {
        if (config.token == address(0)) {
            revert InvalidConfig();
        }

        _token = config.token;
        _maxLevel = config.maxLevel;
        _perLevelPercentage = config.perLevelPercentage;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Rewward distribution                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Distribute the rewards to the referrer of the referee
    function _distributeReferralRewards(bytes32 _tree, address _referee, bool _includeReferee, uint256 _initialReward)
        internal
    {
        // Check if the campaign is active
        if (!_referralCampaignStorage().isActive) {
            revert InactiveCampaign();
        }

        // Current recipient
        address currentRecipient = _includeReferee ? _referee : getReferrer(_tree, _referee);
        // Early exit if no _currentRecipient
        if (currentRecipient == address(0)) {
            return;
        }

        // Current iter level
        uint256 level = 0;
        uint256 rewardAirdrop = _initialReward;

        // Loop thrgouh the levels
        while (currentRecipient != address(0) && level < _maxLevel) {
            // Add a reward for the user
            _pushReward(currentRecipient, _token, rewardAirdrop);
            // Move to the next level
            currentRecipient = getReferrer(_tree, currentRecipient);
            level++;
            rewardAirdrop = (rewardAirdrop * _perLevelPercentage) / 10_000;
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               State managment                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Pause the campaign
    function _pauseCampaign() internal {
        _referralCampaignStorage().isActive = false;
    }

    /// @dev Resume the campaign
    function _resumeCampaign() internal {
        _referralCampaignStorage().isActive = true;
    }

    /* -------------------------------------------------------------------------- */
    /*                                View methods                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the current contract config
    function getReferralCampaignConfig() external view returns (CampaignConfig memory) {
        return CampaignConfig({maxLevel: _maxLevel, perLevelPercentage: _perLevelPercentage, token: _token});
    }
}
