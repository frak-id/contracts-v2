// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Kernel} from "kernel/Kernel.sol";
import {IValidator} from "kernel/interfaces/IERC7579Modules.sol";

import {ValidationId} from "kernel/types/Types.sol";
import {ValidatorLib} from "kernel/utils/ValidationTypeLib.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @author @KONFeature
/// @title NexusFactory
/// @notice Contract permitting to deploy Kernel smart account with webauthn validator, using minal calldata to reduce cost on L2
/// @custom:security-contact contact@frak.id
contract NexusFactory {
    error InitializeError();

    /// @dev The current kernel reference implementation
    address private immutable _implementation;

    /// @dev The current kernel validator
    IValidator private immutable _validator;

    constructor(address _impl, address _webAuthnValidator) {
        _implementation = _impl;
        _validator = IValidator(_webAuthnValidator);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Account creation methods                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Create a new account with the given webauthn data
    function createAccount(bytes calldata _webAuthNEnableData, bytes32) public payable returns (address) {
        //TODO: The 2 first byte should be the version, that match an implementation
        //TODO: Only owner role update implementation and validator

        // Get the salt for the init data
        bytes32 salt = _getNoHookInitSalt(_webAuthNEnableData);

        // Try to deploy the account
        (bool alreadyDeployed, address account) = LibClone.createDeterministicERC1967(msg.value, _implementation, salt);

        // Early exit if already deployed
        if (alreadyDeployed) {
            return account;
        }

        // Otherwise, call the init data
        bytes memory initData = _getNoHookInitData(_webAuthNEnableData);
        (bool success,) = account.call(initData);
        if (!success) {
            revert InitializeError();
        }
        return account;
    }

    /* -------------------------------------------------------------------------- */
    /*                          Init data builder methods                         */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the init data with no hooks
    function _getNoHookInitData(bytes calldata _webAuthNEnableData) private view returns (bytes memory initData) {
        ValidationId vId = ValidatorLib.validatorToIdentifier(_validator);
        // Encode the init function call
        initData = abi.encodeWithSelector(Kernel.initialize.selector, vId, address(0), _webAuthNEnableData, "");
    }

    /// @dev Get the init data with no hooks
    function _getNoHookInitSalt(bytes calldata _webAuthNEnableData) private pure returns (bytes32 salt) {
        // Compute the salt (solely based on the webauthn data)
        salt = keccak256(_webAuthNEnableData);
    }

    /* -------------------------------------------------------------------------- */
    /*                                View methods                                */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the address of the account with the given data
    function getAddress(bytes calldata _webAuthNEnableData) public view returns (address) {
        // Get the salt for the init data
        bytes32 salt = _getNoHookInitSalt(_webAuthNEnableData);
        // Rebuild the salt
        return LibClone.predictDeterministicAddressERC1967(_implementation, salt, address(this));
    }

    /// @dev Get the current factory config
    function getConfig() public view returns (address implementation, address validator) {
        return (_implementation, address(_validator));
    }
}
