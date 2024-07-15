// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionDelegatorAction} from "./InteractionDelegatorAction.sol";
import {UserOperation} from "I4337/interfaces/UserOperation.sol";
import {Kernel} from "kernel-v2/Kernel.sol";
import {ValidAfter, ValidUntil, ValidationData, packValidationData} from "kernel-v2/common/Types.sol";
import {IKernelValidator} from "kernel-v2/interfaces/IKernelValidator.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {EIP712} from "solady/utils/EIP712.sol";

ValidationData constant SIG_VALIDATION_FAILED = ValidationData.wrap(1);

/// @author @KONFeature
/// @title InteractionDelegatorValidator
/// @notice A validator used to validate interaction delegator interaction of this wallet.
contract InteractionDelegatorValidator is IKernelValidator {
    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Address of the interaction delegator
    address internal immutable _DELEGATOR_ADDRESS;

    constructor(address _delegatorAddress) {
        _DELEGATOR_ADDRESS = _delegatorAddress;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Installation hooks                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Initialise the session for the given smart account
    function enable(bytes calldata) external payable override {}

    /// @dev Disable the session for the given smart account
    function disable(bytes calldata) external payable override {}

    /* -------------------------------------------------------------------------- */
    /*                              Validation hooks                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Not allowed for delegator interaction
    function validateUserOp(UserOperation calldata, bytes32, uint256)
        external
        payable
        override
        returns (ValidationData)
    {
        revert NotImplemented();
    }

    /// @notice Not allowed for delegator interaction
    function validateSignature(bytes32, bytes calldata) external pure returns (ValidationData) {
        revert NotImplemented();
    }

    /// @notice Allow only the delegator to call this validator
    function validCaller(address _caller, bytes calldata _data) external view override returns (bool) {
        // If not the delegator requesting, reject
        if (_caller != _DELEGATOR_ADDRESS) {
            return false;
        }

        // Extract the target method of this call
        bytes4 targetMethod = bytes4(_data[0:4]);

        // If it's not an interaction related method, this validator can't be used
        if (
            targetMethod != InteractionDelegatorAction.sendInteraction.selector
                && targetMethod != InteractionDelegatorAction.sendInteractions.selector
        ) {
            return false;
        }

        // If we arrive here, all good
        return true;
    }
}
