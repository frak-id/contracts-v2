// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {CONTENT_TYPE_PRESS, ContentTypes} from "../constants/ContentTypes.sol";
import {INTERACTION_PRESS_USED_SHARE_LINK, InteractionType} from "../constants/InteractionType.sol";
import {PushPullModule} from "../modules/PushPullModule.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {CAMPAIGN_MANAGER_ROLE, InteractionCampaign} from "./InteractionCampaign.sol";
import {InteractionDecoderLib} from "./lib/InteractionDecoderLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @author @KONFeature
/// @title ReferralCampaign
/// @notice Smart contract for a referral based compagn
/// @custom:security-contact contact@frak.id
contract ReferralCampaign is InteractionCampaign, PushPullModule {
    using SafeTransferLib for address;
    using InteractionDecoderLib for bytes;

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
    ReferralRegistry internal immutable _REFERRAL_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.campaign.referral')) - 1)
    bytes32 private constant _REFERRAL_CAMPAIGN_STORAGE_SLOT =
        0x1a8750ce484d3e646837fde7cca6507f02ff36bcb584c0638e67d94a44dffb1f;

    struct ReferralCampaignStorage {
        /// @dev High level pause / resume of the campaign
        bool isActive;
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

    /// @dev Check if the campaign is active or not
    function isActive() public view override returns (bool) {
        // If not active, directly return false
        if (!_referralCampaignStorage().isActive) {
            return false;
        }
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
    function handleInteraction(bytes calldata _data) public override nonReentrant {
        // If the campaign isn't active, directly exit
        if (!isActive()) {
            return;
        }

        // Extract the data
        (InteractionType interactionType, bytes calldata interactionData) = _data.decodeInteraction();

        // If the interaction is a usage of a share link, handle it
        if (interactionType == INTERACTION_PRESS_USED_SHARE_LINK) {
            (, address user) = interactionData.pressDecodeUseShareLink();
            _onUserReferralActivated(user);
        }
    }

    /// @dev Handle the referral activation
    function _onUserReferralActivated(address _user) internal {
        _performTokenDistribution(_user, _INITIAL_REFERRER_REWARD);
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

    function setActive(bool activate) external nonReentrant onlyRoles(CAMPAIGN_MANAGER_ROLE) {
        _referralCampaignStorage().isActive = activate;
    }
}
