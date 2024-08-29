// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {CONTENT_TYPE_PRESS, ContentTypes} from "../constants/ContentTypes.sol";
import {InteractionType, InteractionTypeLib, ReferralInteractions} from "../constants/InteractionType.sol";
import {ContentInteractionDiamond} from "../interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "../interaction/ContentInteractionManager.sol";
import {PushPullModule} from "../modules/PushPullModule.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {CAMPAIGN_EVENT_EMITTER_ROLE, CAMPAIGN_MANAGER_ROLE, InteractionCampaign} from "./InteractionCampaign.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @author @KONFeature
/// @title ReferralCampaign
/// @notice Smart contract for a referral based compagn
/// @custom:security-contact contact@frak.id
contract ReferralCampaign is InteractionCampaign, PushPullModule {
    using SafeTransferLib for address;
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
    error InactiveCampaign();
    error DistributionCapReached();

    /* -------------------------------------------------------------------------- */
    /*                              Immutable config                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Pourcentage base
    uint256 private constant PERCENT_BASE = 10_000;

    /// @dev The max exploration level of the referral tree
    uint256 private constant MAX_EXPLORATION_LEVEL = 5;

    /// @dev The fixed frak fee rate
    uint256 private constant FRAK_FEE = 2_000; // 20%

    /// @dev The deperdition rate per level
    uint256 private constant DEPERDITION_PER_LEVEL = 8_000; // 80%

    /// @dev The percent for the user
    uint256 private immutable USER_PERCENT;

    /// @dev The initial referrer reward
    uint256 private immutable BASE_REWARD;

    /// @dev The distribution cap
    uint256 private immutable DISTRIBUTION_CAP;

    /// @dev The distribution period
    uint256 private immutable DISTRIBUTION_CAP_PERIOD;

    /// @dev The referral tree for the current content id
    bytes32 private immutable REFERRAL_TREE;

    /// @dev The accounting wallet of frak that will receive the rewards
    address private immutable FRAK_CAMPAIGN;

    /// @dev The referral registry
    ReferralRegistry private immutable REFERRAL_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.campaign.referral')) - 1)
    bytes32 private constant _REFERRAL_CAMPAIGN_STORAGE_SLOT =
        0x1a8750ce484d3e646837fde7cca6507f02ff36bcb584c0638e67d94a44dffb1f;

    /// @custom:storage-location erc7201:frak.campaign.referral
    struct ReferralCampaignStorage {
        /// @dev The start timestamp for the cap computation
        uint48 capStartTimestamp;
        /// @dev The current amount during the given timeframe
        uint208 capDistributedAmount;
        /// @dev The total amount distributed
        uint256 totalDistributedAmount;
        /// @dev Start and end data
        uint48 startDate;
        uint48 endDate;
    }

    function _referralCampaignStorage() private pure returns (ReferralCampaignStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _REFERRAL_CAMPAIGN_STORAGE_SLOT
        }
    }

    struct CampaignConfig {
        // Required config
        address token;
        uint256 initialReward;
        // Percent of the reward for the end users
        uint256 userRewardPercent; // (on a 1/10_000) scale
        // Optional distribution cap infos
        uint256 distributionCapPeriod; // in seconds, can be 3600 for an hour for exmaple
        uint256 distributionCap;
        // Optional data range for the config
        uint48 startDate;
        uint48 endDate;
        // Optional name for the campaign (as bytes32)
        bytes32 name;
    }

    constructor(
        CampaignConfig memory _config,
        ReferralRegistry _referralRegistry,
        address _owner,
        address _frakCampaignWallet,
        ContentInteractionDiamond _interaction
    ) InteractionCampaign(_owner, _interaction, _config.name) PushPullModule(_config.token) {
        if (_config.token == address(0)) {
            revert InvalidConfig();
        }

        // Set every immutable arguments
        REFERRAL_REGISTRY = _referralRegistry;
        USER_PERCENT = _config.userRewardPercent;
        BASE_REWARD = _config.initialReward;
        FRAK_CAMPAIGN = _frakCampaignWallet;

        DISTRIBUTION_CAP = _config.distributionCap;
        DISTRIBUTION_CAP_PERIOD = _config.distributionCapPeriod;

        // Store the referral tree
        REFERRAL_TREE = _interaction.getReferralTree();

        // If we got a start date, set it in storage
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();
        if (_config.startDate != 0) {
            campaignStorage.startDate = _config.startDate;
        }
        if (_config.endDate != 0) {
            campaignStorage.endDate = _config.endDate;
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Campaign status                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the campaign metadata
    function getMetadata() public pure override returns (string memory _type, string memory version) {
        _type = "frak.campaign.referral";
        version = "0.0.1";
    }

    /// @dev Get the campaign config
    function getConfig() public view returns (CampaignConfig memory) {
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();
        InteractionCampaignStorage storage interactionStorage = _interactionCampaignStorage();
        return CampaignConfig({
            token: TOKEN,
            initialReward: BASE_REWARD,
            userRewardPercent: USER_PERCENT,
            distributionCapPeriod: DISTRIBUTION_CAP_PERIOD,
            distributionCap: DISTRIBUTION_CAP,
            startDate: campaignStorage.startDate,
            endDate: campaignStorage.endDate,
            name: interactionStorage.name
        });
    }

    /// @dev Check if the campaign is active or not
    function isActive() public view override returns (bool) {
        // Check if with start and end date
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();

        // If it's not running, directly exit
        if (!_interactionCampaignStorage().isRunning) {
            return false;
        }

        // Otherwise, check the date
        if (campaignStorage.startDate != 0 && block.timestamp < campaignStorage.startDate) {
            return false;
        }
        if (campaignStorage.endDate != 0 && block.timestamp > campaignStorage.endDate) {
            return false;
        }
        // Active only if we can distribute a few rewards
        return TOKEN.balanceOf(address(this)) > BASE_REWARD * 2;
    }

    /// @dev Check if the given campaign support the `_contentType`
    function supportContentType(ContentTypes _contentType) public pure override returns (bool) {
        // Only supporting press content
        return _contentType.hasReferralFeature();
    }

    /* -------------------------------------------------------------------------- */
    /*                         Campaign distribution logic                        */
    /* -------------------------------------------------------------------------- */

    /// @dev Handle the given interaction
    function handleInteraction(bytes calldata _data) public override onlyRoles(CAMPAIGN_EVENT_EMITTER_ROLE) {
        // If the campaign isn't active, directly exit
        if (!isActive()) {
            revert InactiveCampaign();
        }

        // Extract the data
        (InteractionType interactionType, address user,) = _data.unpackForCampaign();

        // If the interaction is a usage of a share link, handle it
        if (interactionType == ReferralInteractions.REFERRED) {
            _performTokenDistribution(user, BASE_REWARD);
        }
    }

    /// @dev External method callable by the manager, to distribute token to all the user referrers
    function distributeTokenToUserReferrers(address _user, uint256 _initialAmount)
        external
        onlyRoles(CAMPAIGN_MANAGER_ROLE)
    {
        // If the campaign isn't active, directly exit
        if (!isActive()) {
            revert InactiveCampaign();
        }
        _performTokenDistribution(_user, _initialAmount);
    }

    /// @dev Perform a token distrubtion for all the referrers of `_user`, with the initial amount to `_amount`
    function _performTokenDistribution(address _user, uint256 _amount) internal {
        // Get all the referrers
        address[] memory referrers = REFERRAL_REGISTRY.getCappedReferrers(REFERRAL_TREE, _user, MAX_EXPLORATION_LEVEL);

        // Early exit if no saved referrers (shouldn't be the case, be safety first)
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
                uint256 userAmount = (remainingAmount * USER_PERCENT) / PERCENT_BASE;
                rewards[1] = Reward(_user, userAmount);
                // Decrease the amount
                remainingAmount -= userAmount;
            }

            // Iterate over each referrers
            for (uint256 i = 0; i < referrers.length; i++) {
                // Build the reward
                uint256 reward = (remainingAmount * DEPERDITION_PER_LEVEL) / PERCENT_BASE;
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
            _pushRewards(rewards);

            // If we have no cap, exit
            if (DISTRIBUTION_CAP == 0) {
                return;
            }

            // Update the cap
            _updateDistributionCap(_amount);
        }
    }

    /// @dev Update the distribution cap
    /// @dev  And reset it if needed
    function _updateDistributionCap(uint256 _distributedAmount) private {
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();

        unchecked {
            // Update the total distributed amount
            campaignStorage.totalDistributedAmount += _distributedAmount;

            // Cap reset case
            if (block.timestamp > campaignStorage.capStartTimestamp + DISTRIBUTION_CAP_PERIOD) {
                emit DistributionCapReset(campaignStorage.capStartTimestamp, campaignStorage.capDistributedAmount);

                campaignStorage.capStartTimestamp = uint48(block.timestamp);
                campaignStorage.capDistributedAmount = uint208(_distributedAmount);

                return;
            }
            // Check if we can distribute the reward
            if (campaignStorage.capDistributedAmount + _distributedAmount > DISTRIBUTION_CAP) {
                revert DistributionCapReached();
            }
            campaignStorage.capDistributedAmount += uint208(_distributedAmount);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                           Campaign Administration                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Withdraw the remaining token from the campaign
    function withdraw() external nonReentrant onlyRoles(CAMPAIGN_MANAGER_ROLE) {
        TOKEN.safeTransfer(msg.sender, TOKEN.balanceOf(address(this)));
    }

    /// @dev Update the campaign activation date
    function setActivationDate(uint48 _startDate, uint48 _endDate)
        external
        nonReentrant
        onlyRoles(CAMPAIGN_MANAGER_ROLE)
    {
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();
        campaignStorage.startDate = _startDate;
        campaignStorage.endDate = _endDate;
    }
}
