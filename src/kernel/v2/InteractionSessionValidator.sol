// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentInteractionAction} from "./ContentInteractionAction.sol";
import {UserOperation} from "I4337/interfaces/UserOperation.sol";
import {Kernel} from "kernel-v2/Kernel.sol";
import {ValidAfter, ValidUntil, ValidationData, packValidationData} from "kernel-v2/common/Types.sol";
import {IKernelValidator} from "kernel-v2/interfaces/IKernelValidator.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {EIP712} from "solady/utils/EIP712.sol";

ValidationData constant SIG_VALIDATION_FAILED = ValidationData.wrap(1);

/// @dev Storage layout for a session
struct InteractionSessionValidatorStorage {
    // From when the session is allowed
    uint48 sessionStart;
    // Until when the session is allowed
    uint48 sessionEnd;
    // The session validator
    address sessionValidator;
}

/// @dev The initialisation data for a session
struct InteractionSessionInitializationData {
    // The duration of the session
    uint256 sessionStart;
    // The duration of the session
    uint256 sessionEnd;
    // The session validator
    address sessionValidator;
}

/// @author @KONFeature
/// @title InteractionSessionValidator
/// @notice A validator used to validate using interactions on contents.
contract InteractionSessionValidator is IKernelValidator, EIP712 {
    /// @dev EIP-712 typehash used to validate the given user op
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH = keccak256("ValidateInteractionOp(bytes32 userOpHash)");

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a session is enabled
    event InteractionSessionEnabled(
        address indexed wallet, address sessionValidator, uint256 sessionStart, uint256 sessionEnd
    );

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev When the param to enable this validator are invalid
    error InvalidEnableParams();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Mapping of smart account address to each webAuthn specific storage
    mapping(address smartAccount => InteractionSessionValidatorStorage sessionStorage) private sessionStorage;

    /* -------------------------------------------------------------------------- */
    /*                               EIP-712 related                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Name and version for the EIP-712
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "Frak.InteractionSessionValidator";
        version = "0.0.1";
    }

    /// @dev Expose the domain separator
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    /* -------------------------------------------------------------------------- */
    /*                             Installation hooks                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Initialise the session for the given smart account
    function enable(bytes calldata _data) external payable override {
        // Extract the init data
        InteractionSessionInitializationData calldata initData;
        assembly {
            initData := _data.offset
        }

        // Ensure params are valid
        if (
            initData.sessionStart > initData.sessionEnd || block.timestamp > initData.sessionEnd
                || initData.sessionValidator == address(0)
        ) {
            revert InvalidEnableParams();
        }

        // Store the session
        sessionStorage[msg.sender] = InteractionSessionValidatorStorage({
            sessionStart: uint48(initData.sessionStart),
            sessionEnd: uint48(initData.sessionEnd),
            sessionValidator: initData.sessionValidator
        });

        // Emit the event
        emit InteractionSessionEnabled(
            msg.sender, initData.sessionValidator, initData.sessionStart, initData.sessionEnd
        );
    }

    /// @dev Disable the session for the given smart account
    function disable(bytes calldata) external payable override {
        delete sessionStorage[msg.sender];
    }

    /// @dev Fetch the current `wallet` session
    function getCurrentSession(address _wallet) external view returns (InteractionSessionValidatorStorage memory) {
        return sessionStorage[_wallet];
    }

    /* -------------------------------------------------------------------------- */
    /*                              Validation hooks                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Validate the given `_userOp`.
    function validateUserOp(UserOperation calldata _userOp, bytes32 _userOpHash, uint256)
        external
        payable
        override
        returns (ValidationData)
    {
        // Check that the account have a session
        InteractionSessionValidatorStorage storage validatorStorage = sessionStorage[_userOp.sender];
        if (validatorStorage.sessionValidator == address(0)) {
            return SIG_VALIDATION_FAILED;
        }

        // Extract the target method of this user operation
        bytes4 targetMethod = bytes4(_userOp.callData[0:4]);

        // If it's not an interaction related method, this validator can't be used
        if (
            targetMethod != ContentInteractionAction.sendInteraction.selector
                && targetMethod != ContentInteractionAction.sendInteractions.selector
        ) {
            return SIG_VALIDATION_FAILED;
        }

        // Rebuild the full typehash
        // No need for nonce checking since it's already done on the account level
        bytes32 digest = _hashTypedData(keccak256(abi.encode(_VALIDATE_INTERACTION_TYPEHASH, _userOpHash)));

        // Retreive the signer
        address signer = ECDSA.tryRecoverCalldata(digest, _userOp.signature);
        // No need to check for address(0) here since it's already done in the session validator
        if (signer != validatorStorage.sessionValidator) {
            return SIG_VALIDATION_FAILED;
        }

        // If valid, the signature is only valid for the given duration
        return packValidationData(
            ValidAfter.wrap(validatorStorage.sessionStart), ValidUntil.wrap(validatorStorage.sessionEnd)
        );
    }

    /// @notice Not allowed for interaction session
    function validateSignature(bytes32, bytes calldata) external pure returns (ValidationData) {
        revert NotImplemented();
    }

    /// @notice Not allowed for interaction session
    function validCaller(address, bytes calldata) external pure override returns (bool) {
        revert NotImplemented();
    }
}
