// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Interaction, InteractionDelegatorAction} from "./InteractionDelegatorAction.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {LibZip} from "solady/utils/LibZip.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";

/// @author @KONFeature
/// @title InteractionDelegator
/// @notice The delegator that will be responsible to push user interactions
contract InteractionDelegator is OwnableRoles {
    using LibZip for bytes;

    constructor() {
        // Set the roles
        _initializeOwner(msg.sender);
        _setRoles(msg.sender, DELEGATION_EXECUTOR_ROLE);
    }

    /// @dev Represent a delegated interaction
    struct DelegatedInteraction {
        address wallet;
        uint256 contentId;
        bytes data;
    }

    /// @dev The execute the given `_compressed` interactions on the behalf of the users
    function execute(bytes calldata _compressed) external onlyRoles(DELEGATION_EXECUTOR_ROLE) {
        // Parse the interactions
        DelegatedInteraction[] memory interactions = abi.decode(_compressed.cdDecompress(), (DelegatedInteraction[]));

        // Execute the interactions
        for (uint256 i = 0; i < interactions.length; i++) {
            DelegatedInteraction memory interaction = interactions[i];
            // Map to smart wallet
            InteractionDelegatorAction walletAction = InteractionDelegatorAction(interaction.wallet);
            // Execute the interaction (we don't handle error)
            try walletAction.sendInteraction(Interaction(interaction.contentId, interaction.data)) {} catch {}
        }
    }
}

/**
 * Interaction delegator should be:
 *   - Callabvle only by a KMS signer on the Nexus side
 *   - Recieve LZ compressed call data and execute them
 *   - Batch multiple smart account interactions
 *   - Format of the interactions:
 *     - caller
 *     - interactions[]
 *   - Single entry point being:
 *     - pushInteractions(bytes calldata _compressed)
 *
 * InteractionDelegatorValidator should be:
 *   - Check the we are only calling single or ultiple interaction endpoints
 *   - Check that the caller is the interaction delegator
 *   - Can't execute user op or validate signature on the behalf of the user
 *   - Only implement valid caller with the right data
 */

/// @dev The role required to execute interaction
uint256 constant DELEGATION_EXECUTOR_ROLE = 1 << 1;
