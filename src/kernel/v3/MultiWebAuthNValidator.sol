// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {IValidator, IHook} from "kernel/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "kernel/interfaces/PackedUserOperation.sol";
import {
    SIG_VALIDATION_SUCCESS_UINT,
    SIG_VALIDATION_FAILED_UINT,
    ERC1271_MAGICVALUE,
    ERC1271_INVALID,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_HOOK
} from "kernel/types/Constants.sol";
import {WebAuthnVerifier} from "../utils/WebAuthnVerifier.sol";

struct WebAuthNPubKey {
    /// @dev The `x` coord of the secp256r1 public key used to sign the user operation.
    uint256 x;
    /// @dev The `y` coord of the secp256r1 public key used to sign the user operation.
    uint256 y;
}

/// @dev Storage layout for a smart account in the WebAuthNValidator contract.
struct MultiWebAuthNValidatorStorage {
    /// @dev The default authenticator id to use
    bytes32 mainAuthenticatorIdHash;
    // Mapping of authenticator id to public key
    mapping(bytes32 authenticatorIdHash => WebAuthNPubKey pubKey) pubKeys;
}

/// @dev The initialisation data for the WebAuthN validator.
struct WebAuthNInitializationData {
    /// @dev The authenticator id used to create the public key, base64 encoded, used to find the public key on-chain post creation.
    bytes32 authenticatorIdHash;
    uint256 x;
    uint256 y;
}

/// @author @KONFeature
/// @title MultiWebAuthNValidator
/// @notice A Multi-WebAuthN validator for erc-7579 compliant smart wallet, based on the FCL approach arround WebAuthN signature handling
/// @notice This validator can have multiple webauthn validator per wallet, can revoke them etc.
contract MultiWebAuthNValidatorV3 is IValidator {
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a public key signing the WebAuthN user operation is added for a given `smartAccount`.
    /// @dev The `authenticatorIdHash` param represent the webauthn authenticator id used to create this public key
    event WebAuthnPublicKeyAdded(
        address indexed smartAccount, bytes32 indexed authenticatorIdHash, uint256 x, uint256 y
    );

    /// @dev Event emitted when a public key signing the WebAuthN user operation is revoked for a given `smartAccount`.
    /// @dev The `authenticatorIdHash` param represent the revoked authenticator
    event WebAuthnPublicKeyRemoved(address indexed smartAccount, bytes32 indexed authenticatorIdHash);

    /// @dev Event emitted when the main passkey has changed for the given `smartAccount`.
    event PrimaryPassKeyChanged(address indexed smartAccount, bytes32 indexed authenticatorIdHash);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev When the initialisation data of this validator are invalid
    error InvalidInitData(uint256 x, uint256 y);

    /// @dev When  a passkey isn't setup yet
    error PassKeyDontExist(address smartAccount, bytes32 authenticatorIdHash);

    /// @dev When the user try to add an existing passkey
    error PassKeyAlreadyExist(address smartAccount, bytes32 authenticatorIdHash);

    /// @dev When the user try to remove the main passkey of his validator
    error CantRemoveMainPasskey(address smartAccount, bytes32 authenticatorIdHash);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Mapping of smart account address to each webAuthn specific storage
    mapping(address smartAccount => MultiWebAuthNValidatorStorage webAuthnStorage) private signerStorage;

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
        return signerStorage[smartAccount].mainAuthenticatorIdHash != 0;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Management methods                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Add a new passkey for a webauthn wallet
    function addPassKey(bytes32 authenticatorId, uint256 x, uint256 y) public {
        // Check if not init (do that here directly to keep the storage pointer referenc)
        MultiWebAuthNValidatorStorage storage validatorStorage = signerStorage[msg.sender];
        if (validatorStorage.mainAuthenticatorIdHash == 0) revert NotInitialized(msg.sender);

        // Ensure the passkey doesn't exist for this user
        WebAuthNPubKey storage pubKey = validatorStorage.pubKeys[authenticatorId];
        if (pubKey.x != 0 || pubKey.y != 0) {
            revert PassKeyAlreadyExist(msg.sender, authenticatorId);
        }

        // Set it and emit the event
        pubKey.x = x;
        pubKey.y = y;

        // Emit the addition event
        emit WebAuthnPublicKeyAdded(msg.sender, authenticatorId, x, y);
    }

    /// @dev Remove a passkey from the
    function removePassKey(bytes32 authenticatorId) public {
        // Check if not init
        MultiWebAuthNValidatorStorage storage validatorStorage = signerStorage[msg.sender];
        if (validatorStorage.mainAuthenticatorIdHash == 0) revert NotInitialized(msg.sender);
        if (validatorStorage.mainAuthenticatorIdHash == authenticatorId) {
            revert CantRemoveMainPasskey(msg.sender, authenticatorId);
        }

        // Then, remove iit
        delete validatorStorage.pubKeys[authenticatorId];
    }

    /// @dev Change the primary pass key
    function setPrimaryPassKey(bytes32 authenticatorId) public {
        MultiWebAuthNValidatorStorage storage validatorStorage = signerStorage[msg.sender];
        if (validatorStorage.mainAuthenticatorIdHash == 0) revert NotInitialized(msg.sender);

        // Ensure the passkey exist
        WebAuthNPubKey storage pubKey = validatorStorage.pubKeys[authenticatorId];
        if (pubKey.x == 0 || pubKey.y == 0) {
            revert PassKeyDontExist(msg.sender, authenticatorId);
        }

        // Otherwise, update the primary one and exit
        validatorStorage.mainAuthenticatorIdHash = authenticatorId;
        emit PrimaryPassKeyChanged(msg.sender, authenticatorId);
    }

    /// @dev Get a passkey for the given authenticator id
    function getPasskey(address _smartWallet, bytes32 _authenticatorId)
        external
        view
        returns (bytes32, WebAuthNPubKey memory)
    {
        return (_authenticatorId, signerStorage[_smartWallet].pubKeys[_authenticatorId]);
    }

    /// @dev Get the primary passkey for the given smart wallet
    function getPasskey(address _smartWallet) external view returns (bytes32, WebAuthNPubKey memory) {
        bytes32 authenticatorId = signerStorage[_smartWallet].mainAuthenticatorIdHash;
        return (authenticatorId, signerStorage[_smartWallet].pubKeys[authenticatorId]);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Installation hooks                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Install WebAuthn validator for a smart account.
    /// @dev The smart account need to be the `msg.sender`.
    /// @dev The public key is encoded as `abi.encode(MultiWebAuthNValidatorStorage)` inside the data, so (uint256,uint256).
    /// @dev The authenticatorIdHash is the hash of the authenticatorId. It enables to find public keys on-chain via event logs.
    function onInstall(bytes calldata _data) external payable override {
        // check if the webauthn validator is already initialized for the given account
        // TODO: This imply that if a smart wallet want to change he need to disable and renable in the same tx, rly wanted? In the meantime it prevent erasing of the biometry validator if the account is compromised
        if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);

        // Extract the init data
        WebAuthNInitializationData calldata initData;
        assembly {
            initData := _data.offset
        }

        // Extract x and y
        (bytes32 authentId, uint256 pubKeyX, uint256 pubKeyY) = (initData.authenticatorIdHash, initData.x, initData.y);

        // Ensure the public key is valid
        if (pubKeyX == 0 || pubKeyY == 0) {
            revert InvalidInitData(pubKeyX, pubKeyY);
        }

        // Set the authentication data
        MultiWebAuthNValidatorStorage storage validatorStorage = signerStorage[msg.sender];
        validatorStorage.mainAuthenticatorIdHash = authentId;
        validatorStorage.pubKeys[authentId].x = pubKeyX;
        validatorStorage.pubKeys[authentId].y = pubKeyY;

        // And emit the event
        emit WebAuthnPublicKeyAdded(msg.sender, authentId, pubKeyX, pubKeyY);
        emit PrimaryPassKeyChanged(msg.sender, authentId);
    }

    /// @notice Uninstall WebAuthn validator for a smart account.
    /// @dev The smart account need to be the `msg.sender`.
    function onUninstall(bytes calldata) external payable override {
        if (!isInitialized(msg.sender)) revert NotInitialized(msg.sender);
        bytes32 mainAuthenticator = signerStorage[msg.sender].mainAuthenticatorIdHash;
        delete signerStorage[msg.sender].pubKeys[mainAuthenticator];
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

    /// @dev layout of a signature (used to extract the reauired payload from the initial calldata)
    struct SignatureLayout {
        bool useOnChainP256Verifier;
        bytes32 authenticatorIdHash;
        WebAuthnVerifier.FclSignatureLayout fclSignature;
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
        // Extract the signature
        SignatureLayout calldata signature;
        assembly {
            signature := _signature.offset
        }

        // Ensure pub key exist here (and copy it into memory)
        WebAuthNPubKey memory pubKey = signerStorage[_sender].pubKeys[signature.authenticatorIdHash];
        if (pubKey.x == 0 || pubKey.y == 0) {
            return false;
        }

        // If the signature is using the on-chain p256 verifier, we will use it
        address p256Verifier = P256_VERIFIER;
        if (signature.useOnChainP256Verifier) {
            p256Verifier = WebAuthnVerifier.PRECOMPILED_P256_VERIFIER;
        }

        // Extract the first byte of the signature to check
        return
            WebAuthnVerifier._verifyWebAuthNSignature(p256Verifier, _hash, signature.fclSignature, pubKey.x, pubKey.y);
    }
}
