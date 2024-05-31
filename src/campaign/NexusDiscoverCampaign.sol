// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InvalidConfig} from "../constants/Errors.sol";

import {CAMPAIGN_MANAGER_ROLE} from "../constants/Roles.sol";
import {CampaignConfig, ReferralCampaignModule} from "../modules/ReferralCampaignModule.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/// @author @KONFeature
/// @title NexusRegisterCampaign
/// @notice Contract used for a registration campagn
/// @custom:security-contact contact@frak.id
contract NexusDiscoverCampaign is ReferralCampaignModule, OwnableRoles {
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when the initial airdrop is distributed
    event RegistrationAirdropDistributed(address indexed user);

    /// @dev Event emitted when the airdrop about a content discovery is distributed
    event ContentDiscoveryAirdropDistributed(address indexed user, uint256 contentId);

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev The tree for new registration
    bytes32 private constant _REGISTRATION_TREE = keccak256("RegistrationReferralTree");

    /// @dev The initial reward for a registration
    uint256 private constant _REGISTRATION_INITIAL_REWARD = 25 ether;

    /// @dev The initial reward when a user discover a new content
    uint256 private constant _DISCOVER_CONTENT_INITIAL_REWARD = 10 ether;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.campaign.discovery')) - 1)
    bytes32 private constant _DISCOVERY_COMPAIGN_STORAGE_SLOT =
        0x4066c368ab5af70b71517ae3e5ce22d0d5ed4f5b39e39da575c3b8b62db84c5f;

    struct DiscoverCampaignStorage {
        /// @dev Mapping of user to check if he has receive registration airdrop
        mapping(address user => bool hasReceivedAirdrop) registrationAirdrop;
        /// @dev Mapping of user to content id to join community airdrop
        mapping(address user => mapping(uint256 contentId => bool hasReceivedAirdrop)) discoverContentAirdrop;
    }

    function _discoveryCampaignStorage() private pure returns (DiscoverCampaignStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _DISCOVERY_COMPAIGN_STORAGE_SLOT
        }
    }

    //// @dev Construction of our contract
    constructor(address _token, address _owner)
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
        // Check provided token
        if (_token == address(0)) {
            revert InvalidConfig();
        }

        // Init owner
        _initializeOwner(_owner);
        _setRoles(_owner, CAMPAIGN_MANAGER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                       Hooks when a referral is added                       */
    /* -------------------------------------------------------------------------- */

    /// @dev Admin can trigger the reward distribution for a referral
    function distributeInstallationReward(address _referee, address _referrer)
        external
        onlyRoles(CAMPAIGN_MANAGER_ROLE)
    {
        // Check if the user has already received the airdrop
        if (_discoveryCampaignStorage().registrationAirdrop[_referee]) {
            return;
        }

        // Save the referrer
        _saveReferrer(_REGISTRATION_TREE, _referee, _referrer);

        // Update storage
        _discoveryCampaignStorage().registrationAirdrop[_referee] = true;

        // Launch the event
        emit RegistrationAirdropDistributed(_referee);

        // Trigger the reward distribution
        _distributeReferralRewards(_REGISTRATION_TREE, _referee, true, _REGISTRATION_INITIAL_REWARD);

        // Auto withdraw the founds for the user, he will saw it directly in his wallet
        pullReward(_referee);
    }

    /// @dev Admin can trigger the reward distribution for a referral
    function distributeContentDiscoveryReward(address _referee, address _referrer, uint256 _contentId)
        external
        onlyRoles(CAMPAIGN_MANAGER_ROLE)
    {
        // Check if the user has already received the airdrop
        if (_discoveryCampaignStorage().discoverContentAirdrop[_referee][_contentId]) {
            return;
        }

        // Compute the referall tree
        bytes32 referallTree = getContentDiscoveryTree(_contentId);

        // Save the referrer
        _saveReferrer(referallTree, _referee, _referrer);

        // Update storage
        _discoveryCampaignStorage().discoverContentAirdrop[_referee][_contentId] = true;

        // Launch the event
        emit ContentDiscoveryAirdropDistributed(_referee, _contentId);

        // Trigger the reward distribution
        _distributeReferralRewards(referallTree, _referee, false, _DISCOVER_CONTENT_INITIAL_REWARD);
    }

    /* -------------------------------------------------------------------------- */
    /*                               State managment                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Pause the campaign
    function pauseCampaign() external onlyRoles(CAMPAIGN_MANAGER_ROLE) {
        _pauseCampaign();
    }

    /// @dev Pause the campaign
    function resumeCampaign() external onlyRoles(CAMPAIGN_MANAGER_ROLE) {
        _resumeCampaign();
    }

    /* -------------------------------------------------------------------------- */
    /*                            External view methods                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the content discovery tree from a content id
    function getContentDiscoveryTree(uint256 contentId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("ContentDiscoveryTree", contentId));
    }
}
