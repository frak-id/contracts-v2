// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";

/// @dev representation of an interaction
struct Interaction {
    uint256 contentId;
    bytes data;
}

/// @author @KONFeature
/// @title ContentInteractionAction
/// @notice A kernel action used to interaction with content interactions
contract ContentInteractionAction {
    error InteractionFailed();

    /// @dev The content registry
    ContentInteractionManager internal immutable _INTERACTION_MANAGER;

    constructor(ContentInteractionManager _interactionManager) {
        _INTERACTION_MANAGER = _interactionManager;
    }

    /// @dev Send a single interaction
    function sendInteraction(Interaction calldata _interaction) external {
        bool success = _sendInteraction(_interaction);
        if (!success) revert InteractionFailed();
    }

    /// @dev Send multiple interactions
    /// @dev Don't revert if any of them is failing
    function sendInteractions(Interaction[] calldata _interactions) external {
        for (uint256 i = 0; i < _interactions.length; i++) {
            _sendInteraction(_interactions[i]);
        }
    }

    /// @dev Send the given interaction
    function _sendInteraction(Interaction calldata _interaction) internal returns (bool success) {
        // If no content id, directly call the interaction manager with the given data
        if (_interaction.contentId == 0) {
            (success,) = address(_INTERACTION_MANAGER).call(_interaction.data);
        } else {
            // Call the interaction contract of the given content
            (success,) =
                address(_INTERACTION_MANAGER.getInteractionContract(_interaction.contentId)).call(_interaction.data);
        }
    }
}
