// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";

/// @dev representation of an interaction
struct Interaction {
    uint256 productId;
    bytes data;
}

/// @author @KONFeature
/// @title InteractionDelegatorAction
/// @notice A kernel action used to interaction with product interactions
contract InteractionDelegatorAction {
    error InteractionFailed();

    /// @dev The product registry
    ProductInteractionManager internal immutable _INTERACTION_MANAGER;

    constructor(ProductInteractionManager _interactionManager) {
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
        // If no product id, directly call the interaction manager with the given data
        if (_interaction.productId == 0) {
            (success,) = address(_INTERACTION_MANAGER).call(_interaction.data);
        } else {
            // Call the interaction contract of the given product
            (success,) =
                address(_INTERACTION_MANAGER.getInteractionContract(_interaction.productId)).call(_interaction.data);
        }
    }
}
