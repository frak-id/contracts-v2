// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentTypes} from "../constants/ContentTypes.sol";
import {InteractionType} from "../constants/InteractionType.sol";
import {ContentInteractionDiamond} from "../interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "../interaction/ContentInteractionManager.sol";
import {CAMPAIGN_MANAGER_ROLE} from "./InteractionCampaign.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @author @KONFeature
/// @title InteractionCampaign
/// @notice Interface representing a campaign around some interactions
/// @custom:security-contact contact@frak.id
abstract contract InteractionCampaign is OwnableRoles, ReentrancyGuard {
    /// @dev Content id linked to this campaign
    uint256 internal immutable CONTENT_ID;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.campaign')) - 1)
    bytes32 private constant _INTERACTION_CAMPAIGN_STORAGE_SLOT =
        0x4502c16acecc256a847201528afb77b0e7b8fd0eb82752bc0f0a6a604a9c2eb4;

    struct InteractionCampaignStorage {
        /// @dev Is the campaign running or not
        bool isRunning;
        /// @dev Name of the campaign (as bytes32)
        bytes32 name;
    }

    function _interactionCampaignStorage() internal pure returns (InteractionCampaignStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _INTERACTION_CAMPAIGN_STORAGE_SLOT
        }
    }

    constructor(address _owner, ContentInteractionDiamond _interaction, bytes32 _name) {
        CONTENT_ID = _interaction.getContentId();

        _initializeOwner(_owner);
        _setRoles(_owner, CAMPAIGN_MANAGER_ROLE);

        _setRoles(address(_interaction), CAMPAIGN_EVENT_EMITTER_ROLE);

        // Set the campaign in the running state
        InteractionCampaignStorage storage campaignStorage = _interactionCampaignStorage();
        campaignStorage.name = _name;
        campaignStorage.isRunning = true;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Metadata reader                              */
    /* -------------------------------------------------------------------------- */

    function getMetadata() public pure virtual returns (string memory _type, string memory version);

    /* -------------------------------------------------------------------------- */
    /*                               Role managments                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Deregsiter the campaign deployer role for the calling contract
    function disallowMe() public {
        _removeRoles(msg.sender, CAMPAIGN_EVENT_EMITTER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Campaign related                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the campaign is active or not
    function isActive() public view virtual returns (bool);

    /// @dev Check if the given campaign support the `_contentType`
    function supportContentType(ContentTypes _contentType) public view virtual returns (bool);

    /// @dev Handle the given interaction
    function handleInteraction(bytes calldata _data) public virtual;

    /* -------------------------------------------------------------------------- */
    /*                                Running state                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the campaign is running
    function isRunning() public view returns (bool) {
        return _interactionCampaignStorage().isRunning;
    }

    /// @dev Update the campaign running status
    function setRunningStatus(bool _isRunning) external nonReentrant onlyRoles(CAMPAIGN_MANAGER_ROLE) {
        _interactionCampaignStorage().isRunning = _isRunning;
    }
}

/// @dev The role for the a campaign event emitter
uint256 constant CAMPAIGN_EVENT_EMITTER_ROLE = 1 << 2;

/// @dev The role for the a campaign event emitter
uint256 constant CAMPAIGN_MANAGER_ROLE = 1 << 3;
