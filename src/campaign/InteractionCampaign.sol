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
    constructor(address _owner, address _contentInteration_manager) {
        _initializeOwner(_owner);
        _setRoles(_contentInteration_manager, CAMPAIGN_DEPLOYER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Role managments                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Register the campaign deployer role
    function allowInteractionContract(address _interactionContract) public onlyRoles(CAMPAIGN_DEPLOYER_ROLE) {
        _setRoles(_interactionContract, CAMPAIGN_EVENT_EMITTER_ROLE);
    }

    /// @dev Deregsiter the campaign deployer role for the calling contract
    function disallowMe() public {
        // If the user havn't any roles, directly exit
        if (!hasAnyRole(msg.sender, CAMPAIGN_DEPLOYER_ROLE)) {
            return;
        }
        _updateRoles(msg.sender, CAMPAIGN_EVENT_EMITTER_ROLE, false);
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

    /// @dev Handle multiple interactions
    function handleInteractions(bytes[] calldata _datas) public {
        // Just loop over the datas and handle them
        for (uint256 i = 0; i < _datas.length; i++) {
            handleInteraction(_datas[i]);
        }
    }
}

/// @dev The role for the a campaign event emitter
uint256 constant CAMPAIGN_DEPLOYER_ROLE = 1 << 1;

/// @dev The role for the a campaign event emitter
uint256 constant CAMPAIGN_EVENT_EMITTER_ROLE = 1 << 2;
