// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, ReferralInteractions} from "../constants/InteractionType.sol";
import {ProductTypes} from "../constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "../interaction/ProductInteractionDiamond.sol";
import {Reward} from "../modules/PushPullModule.sol";
import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {CampaignBank} from "./CampaignBank.sol";
import {InteractionCampaign} from "./InteractionCampaign.sol";
import {CapConfig, CapState, CappedCampaign} from "./libs/CappedCampaign.sol";
import {RewardChainingConfig} from "./libs/RewardChainingCampaign.sol";
import {ActivationPeriod, TimeLockedCampaign} from "./libs/TimeLockedCampaign.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @dev Representing the config for a reward trigger of the campaign
struct FixedAffiliationTriggerConfig {
    InteractionType interactionType;
    uint256 baseReward;
    uint256 maxCountPerUser;
}

/// @dev Representing the config for the referral campaign
struct AffiliationFixedCampaignConfig {
    // Optional name for the campaign (as bytes32)
    bytes32 name;
    // The associated campaign bank
    CampaignBank campaignBank;
    // Optional distribution cap config
    CapConfig capConfig;
    // Optional activation period for the campaign
    ActivationPeriod activationPeriod;
    // The chaining config;
    RewardChainingConfig chainingConfig;
    // Set of triggers for the campaign
    FixedAffiliationTriggerConfig[] triggers;
}

/// @author @KONFeature
/// @title AffiliationFixedCampaign
/// @notice Represent an affiliation campaign with fixed rewards
/// @custom:security-contact contact@frak.id
contract AffiliationFixedCampaign is InteractionCampaign, CappedCampaign, TimeLockedCampaign {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using InteractionTypeLib for bytes;
    using ReferralInteractions for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error InvalidConfig();

    /* -------------------------------------------------------------------------- */
    /*                              Immutable config                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Pourcentage base
    uint256 private constant PERCENT_BASE = 10_000;

    /// @dev The max exploration level of the referral tree
    uint256 private constant MAX_EXPLORATION_LEVEL = 5;

    /// @dev The referral tree for the current product id
    bytes32 private immutable REFERRAL_TREE;

    /// @dev The referral registry
    ReferralRegistry private immutable REFERRAL_REGISTRY;

    /// @dev The associated bank campaign
    CampaignBank private immutable CAMPAIGN_BANK;

    /// @dev The deperdition of reward per referral level
    uint256 private immutable DEPERDITION_PER_LEVEL;

    /// @dev The user percent of the reward (the rest is distributed accross the referral chain)
    uint256 private immutable USER_PERCENT;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Representing a reward trigger
    struct RewardTrigger {
        uint16 maxCountPerUser;
        uint240 baseReward;
    }

    /// @dev Representing the reward trigger storage, storage location is at:
    ///     (
    ///         bytes32(uint256(keccak256('frak.campaign.affiliation-fixed.trigger')) - 1) &
    ///         0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    ///     ) | _interactionType
    function _trigger(InteractionType _interactionType) private pure returns (RewardTrigger storage storagePtr) {
        assembly {
            storagePtr.slot := or(0x000000009a66eab1dc06cf965a5dd434da376bfb8a26e5a07827dbae9f11e304, _interactionType)
        }
    }

    /// @custom:storage-location erc7201:frak.campaign.affiliation-fixed
    struct AffiliationFixedCampaignStorage {
        // Mapping of user + interaction type to triggered count
        mapping(uint256 userAndInteractionType => uint16 triggeredCount) userTriggeredCount;
    }

    /// @dev bytes32(uint256(keccak256('frak.campaign.affiliation-fixed')) - 1)
    function _storage() private pure returns (AffiliationFixedCampaignStorage storage storagePtr) {
        assembly {
            storagePtr.slot := 0x26def63c545368f8e4b3c82ea9bee91018c15d011c56c2ece861910b7ee72c62
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Init                                    */
    /* -------------------------------------------------------------------------- */

    constructor(
        AffiliationFixedCampaignConfig memory _config,
        ReferralRegistry _referralRegistry,
        ProductAdministratorRegistry _productAdministratorRegistry,
        ProductInteractionDiamond _interaction
    ) InteractionCampaign(_productAdministratorRegistry, _interaction, _config.name) {
        // Early exit if we got no triggers nor campaign bank
        if (_config.triggers.length == 0) {
            revert InvalidConfig();
        }
        if (address(_config.campaignBank) == address(0)) {
            revert InvalidConfig();
        }

        // Set every immutable arguments
        REFERRAL_REGISTRY = _referralRegistry;
        CAMPAIGN_BANK = _config.campaignBank;

        // Store the referral tree
        REFERRAL_TREE = _interaction.getReferralTree();

        // Store chaining config
        USER_PERCENT = _config.chainingConfig.userPercent;
        DEPERDITION_PER_LEVEL = _config.chainingConfig.deperditionPerLevel;

        // Set our config for the distribution cap and period
        _setActivationPeriod(_config.activationPeriod);
        _setCapConfig(_config.capConfig);

        // Iterate over each triggers and set them
        uint256 triggerLength = _config.triggers.length;
        for (uint256 i = 0; i < triggerLength; i++) {
            FixedAffiliationTriggerConfig memory triggerConfig = _config.triggers[i];

            RewardTrigger storage trigger = _trigger(triggerConfig.interactionType);
            trigger.baseReward = triggerConfig.baseReward.toUint240();
            trigger.maxCountPerUser = triggerConfig.maxCountPerUser.toUint16();
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Campaign status                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the campaign metadata
    function getMetadata() public view override returns (string memory _type, string memory version, bytes32 name) {
        _type = "frak.campaign.affiliation-fixed";
        version = "0.0.2";
        name = _interactionCampaignStorage().name;
    }

    /// @dev Get the campaign config
    function getConfig()
        public
        view
        returns (
            CapConfig memory capConfig,
            ActivationPeriod memory activationPeriod,
            CampaignBank bank,
            RewardChainingConfig memory chainingConfig
        )
    {
        capConfig = _capConfig();
        activationPeriod = _activationPeriod();
        bank = CAMPAIGN_BANK;
        chainingConfig = RewardChainingConfig(USER_PERCENT, DEPERDITION_PER_LEVEL);
    }

    /// @dev Check if the campaign is active or not
    function isActive() public view override returns (bool) {
        // If it's not running, directly exit
        if (!_interactionCampaignStorage().isRunning) {
            return false;
        }

        // Check the activation period
        {
            ActivationPeriod storage activationPeriod = _activationPeriod();
            if (
                (activationPeriod.start != 0 && block.timestamp < activationPeriod.start)
                    || (activationPeriod.end != 0 && block.timestamp > activationPeriod.end)
            ) {
                return false;
            }
        }

        // Check if the campaign bank is able to distribute tokens
        return CAMPAIGN_BANK.canDistributeToken(address(this));
    }

    /// @dev Check if the given campaign support the `_productType`
    function supportProductType(ProductTypes _productType) public pure override returns (bool) {
        // Only supporting press product
        return _productType.hasReferralFeature();
    }

    /* -------------------------------------------------------------------------- */
    /*                         Campaign distribution logic                        */
    /* -------------------------------------------------------------------------- */

    /// @dev Handle the given interaction
    /// todo: nonreetrant should be moved up a level
    function innerHandleInteraction(bytes calldata _data) internal override nonReentrant {
        // Extract the data
        (InteractionType interactionType, address user,) = _data.unpackForCampaign();

        // Check if we got a trigger for this interaction
        RewardTrigger storage trigger = _trigger(interactionType);
        if (trigger.baseReward == 0) {
            return;
        }

        // If we got a limit per user, check it
        uint256 countKey;
        if (trigger.maxCountPerUser != 0) {
            assembly {
                countKey := or(user, interactionType)
            }
            if (_storage().userTriggeredCount[countKey] >= trigger.maxCountPerUser) {
                return;
            }
        }

        // Perform the token distribution
        _performTokenDistribution(user, trigger.baseReward);

        // Update the count if we got a computed key (otherwise, we don't care)
        if (countKey != 0) {
            _storage().userTriggeredCount[countKey]++;
        }
    }

    /// @dev Perform a token distrubtion for all the referrers of `_user`, with the initial amount to `_amount`
    function _performTokenDistribution(address _user, uint256 _amount) internal {
        // Get all the referrers
        address[] memory referrers = REFERRAL_REGISTRY.getCappedReferrers(REFERRAL_TREE, _user, MAX_EXPLORATION_LEVEL);

        // Early exit if no saved referrers
        if (referrers.length == 0) {
            return;
        }

        unchecked {
            // Build our reward array
            Reward[] memory rewards = new Reward[](referrers.length + 1);
            uint256 remainingAmount = _amount;

            // First one is the user
            {
                uint256 userAmount = (remainingAmount * USER_PERCENT) / PERCENT_BASE;
                rewards[0] = Reward(_user, userAmount);
                // Decrease the amount
                remainingAmount -= userAmount;
            }

            // Iterate over each referrers
            for (uint256 i = 0; i < referrers.length; i++) {
                // Build the reward
                uint256 reward = (remainingAmount * DEPERDITION_PER_LEVEL) / PERCENT_BASE;
                rewards[i + 1] = Reward(referrers[i], reward);
                // Decrease the reward by the amount distributed
                remainingAmount -= reward;
            }

            // If we got a reward remaining, the last referrer take it
            if (remainingAmount > 0) {
                Reward memory lastReward = rewards[rewards.length - 1];
                rewards[rewards.length - 1] = Reward(lastReward.user, lastReward.amount + remainingAmount);
            }

            // Push all the rewards
            CAMPAIGN_BANK.pushRewards(rewards);

            // If we have no cap, exit
            CapConfig storage capConfig = _capConfig();
            if (capConfig.amount == 0) {
                return;
            }

            // Update the cap
            _updateDistributionCap(_amount);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                           Campaign Administration                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Update the campaign activation period
    function updateActivationPeriod(ActivationPeriod memory _newPeriod) external onlyAllowedManager {
        _setActivationPeriod(_newPeriod);
    }

    /// @dev Update the campaign activation period
    function updateCapConfig(CapConfig memory _config) external onlyAllowedManager {
        _setCapConfig(_config);
    }
}
