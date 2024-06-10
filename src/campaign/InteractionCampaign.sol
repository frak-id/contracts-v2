// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentTypes} from "../constants/ContentTypes.sol";
import {InteractionType} from "../constants/InteractionType.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/// @author @KONFeature
/// @title InteractionCampaign
/// @notice Interface representing a campaign around some content interactions
/// @custom:security-contact contact@frak.id
abstract contract InteractionCampaign is OwnableRoles {
    constructor(address _owner, address _contentInterationManager) {
        _initializeOwner(_owner);
        _setRoles(_owner, CAMPAIGN_MANAGER_ROLE);
        _setRoles(_contentInterationManager, CAMPAIGN_DEPLOYER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Metadata reader                              */
    /* -------------------------------------------------------------------------- */

    function getMetadata() public pure virtual returns (string memory name, string memory version);

    /* -------------------------------------------------------------------------- */
    /*                               Role managments                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Register the campaign deployer role
    function allowInteractionContract(address _interactionContract) public onlyRoles(CAMPAIGN_DEPLOYER_ROLE) {
        _setRoles(_interactionContract, CAMPAIGN_EVENT_EMITTER_ROLE);
    }

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
}

/// @dev The role for the a campaign event emitter
uint256 constant CAMPAIGN_DEPLOYER_ROLE = 1 << 1;

/// @dev The role for the a campaign event emitter
uint256 constant CAMPAIGN_EVENT_EMITTER_ROLE = 1 << 2;

/// @dev The role for the a campaign event emitter
uint256 constant CAMPAIGN_MANAGER_ROLE = 1 << 3;
