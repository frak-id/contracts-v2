// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {SingleWebAuthNSignatureLib} from "../types/SingleWebAuthNSignatureLib.sol";
import {WebAuthnVerifier} from "../utils/WebAuthnVerifier.sol";
import {IHook, IValidator} from "kernel/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "kernel/interfaces/PackedUserOperation.sol";
import {
    ERC1271_INVALID,
    ERC1271_MAGICVALUE,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR,
    SIG_VALIDATION_FAILED_UINT,
    SIG_VALIDATION_SUCCESS_UINT
} from "kernel/types/Constants.sol";

/// @dev Storage layout for a smart account in the WebAuthNValidator contract.
struct WebAuthNValidatorStorage {
    /// @dev The `x` coord of the secp256r1 public key used to sign the user operation.
    uint256 x;
    /// @dev The `y` coord of the secp256r1 public key used to sign the user operation.
    uint256 y;
}

/// @author @KONFeature
/// @title WebAuthNValidator
/// @notice A WebAuthN validator for erc-7579 compliant smart wallet, based on the FCL approach arround WebAuthN signature handling
contract WebAuthNValidatorV3 is IValidator {
    using SingleWebAuthNSignatureLib for bytes;
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when the public key signing the WebAuthN user operation is changed for a given `smartAccount`.
    /// @dev The `authenticatorIdHash` param represent the webauthn authenticator id used to create this public key
    event WebAuthnPublicKeyChanged(
        address indexed smartAccount, bytes32 indexed authenticatorIdHash, uint256 x, uint256 y
    );

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error InvalidInitData(uint256 x, uint256 y);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Mapping of smart account address to each webAuthn specific storage
    mapping(address smartAccount => WebAuthNValidatorStorage webAuthnStorage) private signerStorage;

    /// @dev The address of the on-chain p256 verifier contract (will be used if the user want that instead of the pre-compiled one, that way this validator can work on every chain out of the box while rip7212 is slowly being implemented everywhere)
    address private immutable P256_VERIFIER;

    /// @dev Simple constructor, setting the P256 verifier address
    constructor(address _p256Verifier) {
        P256_VERIFIER = _p256Verifier;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Metadata hooks                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Returns the module type of the validator.
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == MODULE_TYPE_VALIDATOR;
    }

    /// @notice Returns if the validator is initialized for a given smart account.
    function isInitialized(address smartAccount) public view override returns (bool) {
        return signerStorage[smartAccount].x != 0;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Installation hooks                             */
    /* -------------------------------------------------------------------------- */

    /// @dev The initialisation data for the WebAuthN validator.
    struct WebAuthNInstallData {
        /// @dev The authenticator id used to create the public key, base64 encoded, used to find the public key on-chain post creation.
        bytes32 authenticatorIdHash;
        uint256 x;
        uint256 y;
    }

    /// @notice Install WebAuthn validator for a smart account.
    /// @dev The smart account need to be the `msg.sender`.
    /// @dev The public key is encoded as `abi.encode(WebAuthNValidatorStorage)` inside the data, so (uint256,uint256).
    /// @dev The authenticatorIdHash is the hash of the authenticatorId. It enables to find public keys on-chain via event logs.
    function onInstall(bytes calldata _data) external payable override {
        // check if the webauthn validator is already initialized for the given account
        // TODO: This imply that if a smart wallet want to change he need to disable and renable in the same tx, rly wanted? In the meantime it prevent erasing of the biometry validator if the account is compromised
        if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);

        // Extract the init data
        WebAuthNInstallData calldata initData;
        assembly {
            initData := _data.offset
        }

        // Extract x and y
        (uint256 pubKeyX, uint256 pubKeyY) = (initData.x, initData.y);

        // Ensure the public key is valid
        if (pubKeyX == 0 || pubKeyY == 0) {
            revert InvalidInitData(pubKeyX, pubKeyY);
        }

        // Set the authentication data
        WebAuthNValidatorStorage storage validatorStorage = signerStorage[msg.sender];
        validatorStorage.x = pubKeyX;
        validatorStorage.y = pubKeyY;

        // And emit the event
        emit WebAuthnPublicKeyChanged(msg.sender, initData.authenticatorIdHash, pubKeyX, pubKeyY);
    }

    /// @notice Uninstall WebAuthn validator for a smart account.
    /// @dev The smart account need to be the `msg.sender`.
    function onUninstall(bytes calldata) external payable override {
        if (!isInitialized(msg.sender)) revert NotInitialized(msg.sender);
        delete signerStorage[msg.sender];
    }

    /* -------------------------------------------------------------------------- */
    /*                              Validation hooks                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Validate the given `_userOp`.
    function validateUserOp(PackedUserOperation calldata _userOp, bytes32 _userOpHash)
        external
        payable
        override
        returns (uint256)
    {
        return _checkSignature(_userOp.sender, _userOpHash, _userOp.signature)
            ? SIG_VALIDATION_SUCCESS_UINT
            : SIG_VALIDATION_FAILED_UINT;
    }

    /// @notice Verify the signature of the given `_hash` by the `_sender`.
    function isValidSignatureWithSender(address _sender, bytes32 _hash, bytes calldata _data)
        external
        view
        returns (bytes4)
    {
        return _checkSignature(_sender, _hash, _data) ? ERC1271_MAGICVALUE : ERC1271_INVALID;
    }

    /// @notice Validates the given `_signature` against the `_hash` for the given `_sender`
    /// @param _sender The sender for which we want to verify the signature
    /// @param _hash The hash signed
    /// @param _signature The signature
    function _checkSignature(address _sender, bytes32 _hash, bytes calldata _signature)
        private
        view
        returns (bool isValid)
    {
        // Access the storage
        WebAuthNValidatorStorage storage validatorStorage = signerStorage[_sender];

        // If the signature is using the on-chain p256 verifier, we will use it
        address p256Verifier;
        if (_signature.useOnChainP256()) {
            p256Verifier = WebAuthnVerifier.PRECOMPILED_P256_VERIFIER;
        } else {
            p256Verifier = P256_VERIFIER;
        }

        // Extract the first byte of the signature to check
        return WebAuthnVerifier._verifyWebAuthNSignature(
            p256Verifier, _hash, _signature.getSignatureBytes(), validatorStorage.x, validatorStorage.y
        );
    }
}
