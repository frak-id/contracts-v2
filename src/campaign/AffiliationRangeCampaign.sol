// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, ReferralInteractions} from "../constants/InteractionType.sol";
import {ProductTypes} from "../constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "../interaction/ProductInteractionDiamond.sol";
import {Reward} from "../modules/PushPullModule.sol";
import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {BetaDistribution} from "../utils/BetaDistribution.sol";
import {CampaignBank} from "./CampaignBank.sol";
import {InteractionCampaign} from "./InteractionCampaign.sol";
import {CapConfig, CapState, CappedCampaign} from "./libs/CappedCampaign.sol";
import {RewardChainingConfig} from "./libs/RewardChainingCampaign.sol";
import {ActivationPeriod, TimeLockedCampaign} from "./libs/TimeLockedCampaign.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @dev Representing the config for a reward trigger of the campaign
struct RangeAffiliationTriggerConfig {
    InteractionType interactionType;
    // Maximum time this trigger can be triggered for a user
    uint256 maxCountPerUser;
    // Start + end reward range
    uint256 startReward;
    uint256 endReward;
    // Beta distribution config
    uint256 percentBeta;
}

/// @dev Representing the config for the affiliation campaign
struct AffiliationRangeCampaignConfig {
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
    RangeAffiliationTriggerConfig[] triggers;
}

/// @author @KONFeature
/// @title AffiliationRangeCampaign
/// @notice Smart contract for a affiliation campaign, distributing token following a beta distribution curve
/// @custom:security-contact contact@frak.id
contract AffiliationRangeCampaign is InteractionCampaign, CappedCampaign, TimeLockedCampaign {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using InteractionTypeLib for bytes;
    using ReferralInteractions for bytes;
    using FixedPointMathLib for uint256;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error InvalidConfig();

    /* -------------------------------------------------------------------------- */
    /*                              Immutable config                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Pourcentage base
    uint256 private constant PERCENT_BASE = 10_000;

    /// @dev Multiplier to map a percent to a WAD point decimals (1e18 / 1e4)
    uint256 private constant PERCENT_TO_WAD = 1e14;

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
        // How many time this trigger could be called for a user
        uint16 maxCountPerUser;
        // Could use a wad multiplier here
        uint48 percentBeta;
        // Reward range (uint96 so support up to 1e10 tokens with 18 decimals)
        uint96 startReward;
        uint96 endReward;
    }

    /// @dev Representing the reward trigger storage, storage location is at:
    ///     (
    ///         bytes32(uint256(keccak256('frak.campaign.affiliation-range.trigger')) - 1) &
    ///         0x0000000011f94d0823f42e20d3b008aff3383a57ec72611438979565cc386185
    ///     ) | _interactionType
    function _trigger(InteractionType _interactionType) private pure returns (RewardTrigger storage storagePtr) {
        assembly {
            storagePtr.slot := or(0x00000000b550be2e7c521e77be22747addea3d6f7ff1122a402603db55359db9, _interactionType)
        }
    }

    /// @custom:storage-location erc7201:frak.campaign.affiliation-range
    struct ReferralCampaignStorage {
        // Mapping of user + interaction type to triggered count
        mapping(uint256 userAndInteractionType => uint16 triggeredCount) userTriggeredCount;
    }

    /// @dev bytes32(uint256(keccak256('frak.campaign.affiliation-range')) - 1)
    function _storage() private pure returns (ReferralCampaignStorage storage storagePtr) {
        assembly {
            storagePtr.slot := 0xf1a57c6146496a7357dccde36c386e0543fac0b700812f07053bb55203c9662d
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Init                                    */
    /* -------------------------------------------------------------------------- */

    constructor(
        AffiliationRangeCampaignConfig memory _config,
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
            RangeAffiliationTriggerConfig memory triggerConfig = _config.triggers[i];

            RewardTrigger storage trigger = _trigger(triggerConfig.interactionType);
            trigger.startReward = triggerConfig.startReward.toUint96();
            trigger.endReward = triggerConfig.endReward.toUint96();
            trigger.percentBeta = triggerConfig.percentBeta.toUint48();
            trigger.maxCountPerUser = triggerConfig.maxCountPerUser.toUint16();
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Campaign status                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the campaign metadata
    function getMetadata() public view override returns (string memory _type, string memory version, bytes32 name) {
        _type = "frak.campaign.affiliation-range";
        version = "0.0.1";
        name = _interactionCampaignStorage().name;
    }

    /// @dev Get the campaign config
    function getConfig()
        public
        view
        returns (CapConfig memory capConfig, ActivationPeriod memory activationPeriod, CampaignBank bank)
    {
        capConfig = _capConfig();
        activationPeriod = _activationPeriod();
        bank = CAMPAIGN_BANK;
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
        RewardTrigger memory trigger = _trigger(interactionType);
        if (trigger.startReward == 0) {
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

        // Get a point on the beta curve following alpha = 2 and beta = trigger.percentBeta
        uint256 wadPoint = BetaDistribution.getBetaWadPoint(uint256(trigger.percentBeta) * PERCENT_TO_WAD);

        // Move this point accross the rward range (0 = start, 1 = end)
        uint256 reward = trigger.startReward + (uint256(trigger.endReward - trigger.startReward)).mulWad(wadPoint);

        // Perform the token distribution (user, reward, userPercent, deperditionPerLevel)
        _performTokenDistribution(user, reward);

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

            // Update the cap
            _updateDistributionCap(_amount);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                           Campaign Administration                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Update the campaign activation period
    function updateActivationPeriod(ActivationPeriod calldata _newPeriod) external onlyAllowedManager {
        _setActivationPeriod(_newPeriod);
    }

    /// @dev Update the campaign activation period
    function updateCapConfig(CapConfig calldata _config) external onlyAllowedManager {
        _setCapConfig(_config);
    }
}
