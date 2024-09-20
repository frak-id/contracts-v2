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
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @dev Representing the config for a reward trigger of the campaign
struct ReferralCampaignTriggerConfig {
    InteractionType interactionType;
    uint256 baseReward;
    uint256 userPercent;
    uint256 deperditionPerLevel;
    uint256 maxCountPerUser;
}

/// @dev Representing the config for the referral campaign
struct ReferralCampaignConfig {
    // Optional name for the campaign (as bytes32)
    bytes32 name;
    // The associated campaign bank
    CampaignBank campaignBank;
    // Set of triggers for the campaign
    ReferralCampaignTriggerConfig[] triggers;
    // Optional distribution cap config
    ReferralCampaign.CapConfig capConfig;
    // Optional activation period for the campaign
    ReferralCampaign.ActivationPeriod activationPeriod;
}

/// @author @KONFeature
/// @title ReferralCampaign
/// @notice Smart contract for a referral based compagn
/// @custom:security-contact contact@frak.id
contract ReferralCampaign is InteractionCampaign {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using InteractionTypeLib for bytes;
    using ReferralInteractions for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when the daily distribution cap is reset
    event DistributionCapReset(uint48 previousTimestamp, uint256 distributedAmount);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error InvalidConfig();
    error DistributionCapReached();

    /* -------------------------------------------------------------------------- */
    /*                              Immutable config                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Pourcentage base
    uint256 private constant PERCENT_BASE = 10_000;

    /// @dev The max exploration level of the referral tree
    uint256 private constant MAX_EXPLORATION_LEVEL = 5;

    /// @dev The fixed frak fee rate
    uint256 private constant FRAK_FEE = 2000; // 20%

    /// @dev The referral tree for the current product id
    bytes32 private immutable REFERRAL_TREE;

    /// @dev The accounting wallet of frak that will receive the rewards
    address private immutable FRAK_CAMPAIGN;

    /// @dev The referral registry
    ReferralRegistry private immutable REFERRAL_REGISTRY;

    /// @dev The associated bank campaign
    CampaignBank private immutable CAMPAIGN_BANK;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Representing a reward trigger
    struct RewardTrigger {
        uint192 baseReward;
        uint16 userPercent;
        uint16 deperditionPerLevel;
        uint16 maxCountPerUser;
    }

    /// @dev Representing the reward trigger storage, storage location is at:
    ///     (
    ///         bytes32(uint256(keccak256('frak.campaign.referral.trigger')) - 1) &
    ///         0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    ///     ) | _interactionType
    function _trigger(InteractionType _interactionType) private pure returns (RewardTrigger storage storagePtr) {
        assembly {
            storagePtr.slot := or(0x2b590e368f6e51c03042de6eb3d37f464929de3b3f869c37f1eb01ab, _interactionType)
        }
    }

    /// @dev Representing the current cap state
    /// @custom:storage-location erc7201:frak.campaign.capState
    struct CapState {
        uint48 startTimestamp;
        uint208 distributedAmount;
    }

    /// @dev bytes32(uint256(keccak256('frak.campaign.referral.capState')) - 1)
    function _capState() private pure returns (CapState storage storagePtr) {
        assembly {
            storagePtr.slot := 0x881caacfc312bc308261b04ba99d456fed46f678c5e99a1782daaeb374ee5ecc
        }
    }

    /// @dev Representing the activation period
    struct ActivationPeriod {
        uint48 start;
        uint48 end;
    }

    /// @dev Representing the cap config
    struct CapConfig {
        // Distribution cap period, in seconds
        uint48 period;
        // Distribution cap amount
        uint208 amount;
    }

    bytes32 private constant _REFERRAL_CAMPAIGN_STORAGE_SLOT =
        0x1a8750ce484d3e646837fde7cca6507f02ff36bcb584c0638e67d94a44dffb1f;

    /// @custom:storage-location erc7201:frak.campaign.referral
    struct ReferralCampaignStorage {
        // Mapping of user + interaction type to triggered count
        mapping(uint256 userAndInteractionType => uint16 triggeredCount) userTriggeredCount;
        /// @dev The distribution cap config
        CapConfig capConfig;
        /// @dev The start date of the campaign
        ActivationPeriod activationPeriod;
    }

    /// @dev bytes32(uint256(keccak256('frak.campaign.referral')) - 1)
    function _referralCampaignStorage() private pure returns (ReferralCampaignStorage storage storagePtr) {
        assembly {
            storagePtr.slot := 0x1a8750ce484d3e646837fde7cca6507f02ff36bcb584c0638e67d94a44dffb1f
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Init                                    */
    /* -------------------------------------------------------------------------- */

    constructor(
        ReferralCampaignConfig memory _config,
        ReferralRegistry _referralRegistry,
        ProductAdministratorRegistry _productAdministratorRegistry,
        address _frakCampaignWallet,
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
        FRAK_CAMPAIGN = _frakCampaignWallet;

        // Store the referral tree
        REFERRAL_TREE = _interaction.getReferralTree();

        // Set our config for the distribution cap and period
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();
        campaignStorage.activationPeriod = _config.activationPeriod;
        campaignStorage.capConfig = _config.capConfig;

        // Iterate over each triggers and set them
        uint256 triggerLength = _config.triggers.length;
        for (uint256 i = 0; i < triggerLength; i++) {
            ReferralCampaignTriggerConfig memory triggerConfig = _config.triggers[i];

            RewardTrigger storage trigger = _trigger(triggerConfig.interactionType);
            trigger.baseReward = triggerConfig.baseReward.toUint192();
            trigger.userPercent = triggerConfig.userPercent.toUint16();
            trigger.deperditionPerLevel = triggerConfig.deperditionPerLevel.toUint16();
            trigger.maxCountPerUser = triggerConfig.maxCountPerUser.toUint16();
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Campaign status                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the campaign metadata
    function getMetadata() public view override returns (string memory _type, string memory version, bytes32 name) {
        _type = "frak.campaign.referral";
        version = "0.0.1";
        name = _interactionCampaignStorage().name;
    }

    /// @dev Get the campaign config
    function getConfig() public view returns (CapConfig memory capConfig, ActivationPeriod memory activationPeriod) {
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();

        capConfig = campaignStorage.capConfig;
        activationPeriod = campaignStorage.activationPeriod;
    }

    /// @dev Check if the campaign is active or not
    function isActive() public view override returns (bool) {
        // Check if with start and end date
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();

        // If it's not running, directly exit
        if (!_interactionCampaignStorage().isRunning) {
            return false;
        }

        // Check the activation period
        ActivationPeriod storage activationPeriod = campaignStorage.activationPeriod;
        if (activationPeriod.start != 0 && block.timestamp < activationPeriod.start) {
            return false;
        }
        if (activationPeriod.end != 0 && block.timestamp > activationPeriod.end) {
            return false;
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
            if (_referralCampaignStorage().userTriggeredCount[countKey] >= trigger.maxCountPerUser) {
                return;
            }
        }

        // Perform the token distribution
        _performTokenDistribution(user, trigger.baseReward, trigger.userPercent, trigger.deperditionPerLevel);

        // Update the count if we got a computed key (otherwise, we don't care)
        if (countKey != 0) {
            _referralCampaignStorage().userTriggeredCount[countKey]++;
        }
    }

    /// @dev Perform a token distrubtion for all the referrers of `_user`, with the initial amount to `_amount`
    function _performTokenDistribution(address _user, uint256 _amount, uint256 _userPercent, uint256 _deperditionLevel)
        internal
    {
        // Get all the referrers
        address[] memory referrers = REFERRAL_REGISTRY.getCappedReferrers(REFERRAL_TREE, _user, MAX_EXPLORATION_LEVEL);

        // Early exit if no saved referrers
        if (referrers.length == 0) {
            return;
        }

        unchecked {
            // Build our reward array
            Reward[] memory rewards = new Reward[](referrers.length + 2);
            uint256 remainingAmount = _amount;

            // First reward is the frak accounting one
            {
                uint256 frkAmount = (_amount * FRAK_FEE) / PERCENT_BASE;
                rewards[0] = Reward(FRAK_CAMPAIGN, frkAmount);
                // Decrease the amount
                remainingAmount -= frkAmount;
            }

            // Second one is the user
            {
                uint256 userAmount = (remainingAmount * _userPercent) / PERCENT_BASE;
                rewards[1] = Reward(_user, userAmount);
                // Decrease the amount
                remainingAmount -= userAmount;
            }

            // Iterate over each referrers
            for (uint256 i = 0; i < referrers.length; i++) {
                // Build the reward
                uint256 reward = (remainingAmount * _deperditionLevel) / PERCENT_BASE;
                rewards[i + 2] = Reward(referrers[i], reward);
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
            CapConfig storage capConfig = _referralCampaignStorage().capConfig;
            if (capConfig.amount == 0) {
                return;
            }

            // Update the cap
            _updateDistributionCap(capConfig, _amount);
        }
    }

    /// @dev Update the distribution cap
    /// @dev  And reset it if needed
    function _updateDistributionCap(CapConfig storage _capConfig, uint256 _distributedAmount) private {
        CapState memory capReadOnly = _capState();

        unchecked {
            // Cap reset case
            if (block.timestamp > capReadOnly.startTimestamp + _capConfig.period) {
                emit DistributionCapReset(capReadOnly.startTimestamp, capReadOnly.distributedAmount);

                _capState().startTimestamp = uint48(block.timestamp);
                _capState().distributedAmount = uint208(_distributedAmount);

                return;
            }
            // Check if we can distribute the reward
            if (capReadOnly.distributedAmount + _distributedAmount > _capConfig.amount) {
                revert DistributionCapReached();
            }
            _capState().distributedAmount += uint208(_distributedAmount);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                           Campaign Administration                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Update the campaign activation period
    function updateActivationPeriod(ActivationPeriod calldata _activationPeriod) external onlyAllowedManager {
        _referralCampaignStorage().activationPeriod = _activationPeriod;
    }

    /// @dev Update the campaign activation period
    function updateCapConfig(CapConfig calldata _capConfig) external onlyAllowedManager {
        _referralCampaignStorage().capConfig = _capConfig;
    }
}
