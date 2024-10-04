// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Interaction, InteractionDelegatorAction} from "./InteractionDelegatorAction.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {LibZip} from "solady/utils/LibZip.sol";

/// @author @KONFeature
/// @title InteractionDelegator
/// @notice The delegator that will be responsible to push user interactions
contract InteractionDelegator is OwnableRoles {
    using LibZip for bytes;

    constructor(address _owner) {
        // Set the roles
        _initializeOwner(_owner);
        _setRoles(_owner, DELEGATION_EXECUTOR_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Simple execution                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Represent a delegated interaction
    struct DelegatedInteraction {
        address wallet;
        Interaction interaction;
    }

    /// @dev The execute the given `_compressed` interactions on the behalf of the users
    function execute(DelegatedInteraction[] calldata _delegatedInteractions)
        external
        onlyRoles(DELEGATION_EXECUTOR_ROLE)
    {
        // Execute the interactions
        for (uint256 i = 0; i < _delegatedInteractions.length; i++) {
            DelegatedInteraction calldata dInteraction = _delegatedInteractions[i];
            // Execute the interaction (we don't handle error)
            try InteractionDelegatorAction(dInteraction.wallet).sendInteraction(dInteraction.interaction) {} catch {}
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              Batched execution                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Represent a delegated interaction
    struct DelegatedBatchedInteraction {
        address wallet;
        Interaction[] interactions;
    }

    /// @dev The execute the given `_compressed` interactions on the behalf of the users
    function executeBatched(DelegatedBatchedInteraction[] calldata _delegatedInteractions)
        external
        onlyRoles(DELEGATION_EXECUTOR_ROLE)
    {
        // Execute the interactions
        for (uint256 i = 0; i < _delegatedInteractions.length; i++) {
            DelegatedBatchedInteraction calldata dInteraction = _delegatedInteractions[i];
            // Execute the interaction (we don't handle error)
            try InteractionDelegatorAction(dInteraction.wallet).sendInteractions(dInteraction.interactions) {} catch {}
        }
    }

    fallback() external payable {
        LibZip.cdFallback();
    }

    receive() external payable {} // Silence compiler warning to add a `receive` function.
}

/// @dev The role required to execute interaction
uint256 constant DELEGATION_EXECUTOR_ROLE = 1 << 1;
