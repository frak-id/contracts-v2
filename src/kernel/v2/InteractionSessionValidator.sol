// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {UserOperation} from "I4337/interfaces/UserOperation.sol";
import {Kernel} from "kernel-v2/Kernel.sol";
import {Call} from "kernel-v2/common/Structs.sol";
import {ValidAfter, ValidUntil, ValidationData, packValidationData} from "kernel-v2/common/Types.sol";
import {IKernelValidator} from "kernel-v2/interfaces/IKernelValidator.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";

ValidationData constant SIG_VALIDATION_FAILED = ValidationData.wrap(1);
ValidationData constant SIG_VALIDATION_SUCCESS = ValidationData.wrap(0);

/// @dev Storage layout for a session
struct InteractionSessionValidatorStorage {
    // From when the session is allowed
    uint48 allowedAfter;
    // Until when the session is allowed
    uint48 allowedUntil;
    // The session validator
    address sessionValidator;
}

/// @dev The initialisation data for a session
struct InteractionSessionInitializationData {
    // The duration of the session
    uint256 allowedAfter;
    // The duration of the session
    uint256 allowedUntil;
    // The session validator
    address sessionValidator;
}

/// @author @KONFeature
/// @title InteractionSessionValidator
/// @notice A validator used to validate using interactions on contents.
contract InteractionSessionValidator is IKernelValidator, EIP712 {
    /// @dev EIP-712 typehash used to validate the given user op
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH =
        keccak256("ValidateInteractionOp(uint256 contentId, address target,bytes32 userOpHash)");

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

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

    /// @dev The content registry
    ContentInteractionManager internal immutable _INTERACTION_MANAGER;

    constructor(ContentInteractionManager _interactionManager) {
        _INTERACTION_MANAGER = _interactionManager;
    }

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
            initData.allowedAfter > initData.allowedUntil || initData.allowedUntil < block.timestamp
                || initData.sessionValidator == address(0)
        ) {
            revert InvalidEnableParams();
        }

        // Store the session
        sessionStorage[msg.sender] = InteractionSessionValidatorStorage({
            allowedAfter: uint48(initData.allowedAfter),
            allowedUntil: uint48(initData.allowedUntil),
            sessionValidator: initData.sessionValidator
        });
    }

    /// @dev Disable the session for the given smart account
    function disable(bytes calldata) external payable override {
        delete sessionStorage[msg.sender];
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

        // Extract content id from signature, and so the allowed target contract
        uint256 contentId = uint256(bytes32(_userOp.signature[0:32]));
        address allowedContract;
        if (contentId == 0) {
            allowedContract = address(_INTERACTION_MANAGER);
        } else {
            allowedContract = _INTERACTION_MANAGER.getInteractionContract(contentId);
        }

        // Ensure that the contractwith which the user op interact are allowed
        if (!_isAllowedTarget(_userOp.callData, allowedContract)) {
            return SIG_VALIDATION_FAILED;
        }

        // Rebuild the full typehash
        // No need for nonce checking since it's already done on the account level
        bytes32 digest = _hashTypedData(
            keccak256(abi.encode(_VALIDATE_INTERACTION_TYPEHASH, contentId, allowedContract, _userOpHash))
        );

        // Retreive the signer
        address signer = ECDSA.tryRecoverCalldata(digest, _userOp.signature[32:]);
        // No need to check for address(0) here since it's already done in the session validator
        if (signer != validatorStorage.sessionValidator) {
            return SIG_VALIDATION_FAILED;
        }

        // If valid, the signature is only valid for the given duration
        return packValidationData(
            ValidAfter.wrap(validatorStorage.allowedAfter), ValidUntil.wrap(validatorStorage.allowedUntil)
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

    function _isAllowedTarget(bytes calldata _userOpData, address _allowedTarget) internal pure returns (bool) {
        // Extract the target method signature (valid is only execute or executeBatch)
        bytes4 targetMethod = bytes4(_userOpData[0:4]);

        // Check the target addresses
        if (targetMethod == Kernel.execute.selector) {
            // Case of a single execution, verify the recipient
            address opTarget = address(bytes20(_userOpData[16:36]));
            return opTarget == _allowedTarget;
        } else if (targetMethod == Kernel.executeBatch.selector) {
            // Case of a batch execution, verify all the targets
            Call[] calldata calls;
            assembly {
                let callsPosition := calldataload(add(_userOpData.offset, 4))

                calls.offset := add(add(_userOpData.offset, 0x24), callsPosition)
                calls.length := calldataload(add(add(_userOpData.offset, 4), callsPosition))
            }

            // Ensure every targets are valid
            for (uint256 i = 0; i < calls.length; i++) {
                if (calls[i].to != _allowedTarget) {
                    return false;
                }
            }

            // If no early exit, the batch calls are good
            return true;
        }

        // If we arrive here, it's invalid
        return false;
    }
}
