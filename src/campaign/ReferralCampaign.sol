// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {CONTENT_TYPE_PRESS, ContentTypes} from "../constants/ContentTypes.sol";
import {InteractionType, InteractionTypeLib, PressInteractions} from "../constants/InteractionType.sol";
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
    using PressInteractions for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when the daily distribution cap is reset
    event DailyDistrubutionCapReset(uint48 previousTimestamp, uint256 distributedAmount);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error InvalidConfig();
    error DailyDistributionCapReached();

    /* -------------------------------------------------------------------------- */
    /*                              Immutable config                              */
    /* -------------------------------------------------------------------------- */

    /// @dev The token to airdrop
    address private immutable _TOKEN;

    /// @dev The exploration level of the referral
    uint256 private immutable _REFERRAL_EXPLORATION_LEVEL;

    /// @dev The percentage of token distributed per level (on 1/10_000 scale)
    uint256 private immutable _PER_LEVEL_PERCENTAGE;

    /// @dev The initial referrer reward
    uint256 private immutable _INITIAL_REFERRER_REWARD;

    /// @dev The daily distribution cap
    uint256 private immutable _DAILY_DISTRIBUTION_CAP;

    /// @dev The referral tree for the current content id
    bytes32 private immutable _REFERRAL_TREE;

    /// @dev The referral registry
    ReferralRegistry private immutable _REFERRAL_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.campaign.referral')) - 1)
    bytes32 private constant _REFERRAL_CAMPAIGN_STORAGE_SLOT =
        0x1a8750ce484d3e646837fde7cca6507f02ff36bcb584c0638e67d94a44dffb1f;

    struct ReferralCampaignStorage {
        /// @dev The start timestamp for the cap computation
        uint48 capStartTimestamp;
        /// @dev The current amount during the given timeframe
        uint208 capDistributedAmount;
        /// @dev The total amount distributed
        uint256 totalDistributedAmount;
    }

    function _referralCampaignStorage() private pure returns (ReferralCampaignStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _REFERRAL_CAMPAIGN_STORAGE_SLOT
        }
    }

    constructor(
        address _token,
        uint256 _explorationLevel,
        uint256 _perLevelPercentage,
        uint256 _initialReferrerReward,
        uint256 _dailyDistributionCap,
        bytes32 _referralTree,
        ReferralRegistry _referralRegistry,
        address _owner,
        address _contentInterationManager
    ) InteractionCampaign(_owner, _contentInterationManager) {
        if (_token == address(0)) {
            revert InvalidConfig();
        }

        // If level > 50% invalid config
        if (_perLevelPercentage > 5_000) {
            revert InvalidConfig();
        }

        // Set everything
        _TOKEN = _token;
        _REFERRAL_EXPLORATION_LEVEL = _explorationLevel;
        _PER_LEVEL_PERCENTAGE = _perLevelPercentage;
        _INITIAL_REFERRER_REWARD = _initialReferrerReward;
        _DAILY_DISTRIBUTION_CAP = _dailyDistributionCap;
        _REFERRAL_REGISTRY = _referralRegistry;
        _REFERRAL_TREE = _referralTree;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Campaign status                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the campaign metadata
    function getMetadata() public pure override returns (string memory name, string memory version) {
        name = "frak.campaign.referral";
        version = "0.0.1";
    }

    /// @dev Check if the campaign is active or not
    function isActive() public view override returns (bool) {
        // Active only if we can distribute a few rewards
        return _TOKEN.balanceOf(address(this)) > _INITIAL_REFERRER_REWARD * 2;
    }

    /// @dev Check if the given campaign support the `_contentType`
    function supportContentType(ContentTypes _contentType) public pure override returns (bool) {
        // Only supporting press content
        return _contentType.isPressType();
    }

    /* -------------------------------------------------------------------------- */
    /*                         Campaign distribution logic                        */
    /* -------------------------------------------------------------------------- */

    /// @dev Handle the given interaction
    function handleInteraction(bytes calldata _data) public override onlyRoles(CAMPAIGN_EVENT_EMITTER_ROLE) {
        // If the campaign isn't active, directly exit
        if (!isActive()) {
            return;
        }

        // Extract the data
        (InteractionType interactionType, address user,) = _data.deocdePackedInteraction();
        bytes4 selector = InteractionType.unwrap(PressInteractions.REFERRED);
        assembly {
            log2(0, 0, 0x10, interactionType)
            log2(0, 0, 0x10, selector)
            log2(0, 0, 0x11, user)
        }

        // If the interaction is a usage of a share link, handle it
        if (interactionType == PressInteractions.REFERRED) {
            _performTokenDistribution(user, _INITIAL_REFERRER_REWARD);
        }
    }

    /// @dev External method callable by the manager, to distribute token to all the user referrers
    function distributeTokenToUserReferrers(address _user, uint256 _initialAmount)
        external
        onlyRoles(CAMPAIGN_MANAGER_ROLE)
    {
        _performTokenDistribution(_user, _initialAmount);
    }

    /// @dev Perform a token distrubtion for all the referrers of `_user`, with the initial amount to `_amount`
    function _performTokenDistribution(address _user, uint256 _amount) internal {
        // Get all the referrers
        address[] memory referrers =
            _REFERRAL_REGISTRY.getCappedReferrers(_REFERRAL_TREE, _user, _REFERRAL_EXPLORATION_LEVEL);

        uint256 totalDistributed;
        uint256 currentReward = _amount;
        for (uint256 i = 0; i < referrers.length; i++) {
            // Distribute the reward
            _pushReward(referrers[i], _TOKEN, currentReward);

            // Update total distributed + current reward
            totalDistributed += currentReward;
            currentReward = (currentReward * _PER_LEVEL_PERCENTAGE) / 10_000;
        }

        // Check with the cap
        ReferralCampaignStorage storage campaignStorage = _referralCampaignStorage();

        // If we reached a new timeframe, reset the cap
        if (block.timestamp > campaignStorage.capStartTimestamp + 1 days) {
            emit DailyDistrubutionCapReset(campaignStorage.capStartTimestamp, campaignStorage.capDistributedAmount);
            campaignStorage.capStartTimestamp = uint48(block.timestamp);
            campaignStorage.capDistributedAmount = uint208(totalDistributed);
        } else {
            // Check if we can distribute the reward
            if (campaignStorage.capDistributedAmount + totalDistributed > _DAILY_DISTRIBUTION_CAP) {
                revert DailyDistributionCapReached();
            }
            campaignStorage.capDistributedAmount += uint208(totalDistributed);
        }

        // Update the total distributed amount
        campaignStorage.totalDistributedAmount += totalDistributed;
    }

    /* -------------------------------------------------------------------------- */
    /*                           Campaign Administration                          */
    /* -------------------------------------------------------------------------- */

    function withdraw() external nonReentrant onlyRoles(CAMPAIGN_MANAGER_ROLE) {
        _TOKEN.safeTransfer(msg.sender, _TOKEN.balanceOf(address(this)));
    }
}
