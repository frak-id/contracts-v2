// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {IKernelValidator} from "kernel-v2/interfaces/IKernelValidator.sol";
import {ValidationData} from "kernel-v2/common/Types.sol";
import {UserOperation} from "I4337/interfaces/UserOperation.sol";
import {WebAuthnVerifier} from "../utils/WebAuthnVerifier.sol";

ValidationData constant SIG_VALIDATION_FAILED = ValidationData.wrap(1);
ValidationData constant SIG_VALIDATION_SUCCESS = ValidationData.wrap(0);

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
/// @notice A Multi-WebAuthN validator for kernel v2 smart wallet, based on the FCL approach arround WebAuthN signature handling
/// @notice This validator can have multiple webauthn validator per wallet, can revoke them etc.
contract MultiWebAuthNValidatorV2 is IKernelValidator {
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

    /// @dev When the smart account sin't init
    error NotInitialized(address smartAccount);

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
    function enable(bytes calldata _data) external payable override {
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
    function disable(bytes calldata) external payable override {
        bytes32 mainAuthenticator = signerStorage[msg.sender].mainAuthenticatorIdHash;
        delete signerStorage[msg.sender].pubKeys[mainAuthenticator];
        delete signerStorage[msg.sender];
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
        return _checkSignature(_userOp.sender, _userOpHash, _userOp.signature)
            ? SIG_VALIDATION_SUCCESS
            : SIG_VALIDATION_FAILED;
    }

    /// @notice Verify the signature of the given `_hash` by the `msg.sender`.
    function validateSignature(bytes32 _hash, bytes calldata _data) external view returns (ValidationData) {
        return _checkSignature(msg.sender, _hash, _data) ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }

    /// @dev Check if the caller is a valid signer, this don't apply to the WebAuthN validator, since it's using a public key
    function validCaller(address, bytes calldata) external pure override returns (bool) {
        revert NotImplemented();
    }

    /// @dev layout of a signature (used to extract the reauired payload from the initial calldata)
    /// TODO: This could be packed AF: bool + bytes32 + challengeOffset + rs packed, then 2 bytes unpacked
    /// TODO: We then would have smth like (byte1 + bytes32 + uint256 + [uint256 + uint256] + bytes + bytes)
    // TODO: then length of the two bytes arrays could be only byte2 (so uint16) (since we can't have more than 255 bytes in a bytes array)
    struct SignatureLayout {
        bool useOnChainP256Verifier;
        bytes32 authenticatorIdHash;
        WebAuthnVerifier.FclSignatureLayout signature;
    }

    /// @notice Validates the given `_signature` against the `_hash` for the given `_sender`
    /// @dev The first 2 bytes of the sig -> use pre compile or not?
    /// @dev The next 32 bytes of the sig -> the authenticator id hash
    /// @dev The rest of the sig -> the webauthn signature data
    /// @param _sender The sender for which we want to verify the signature
    /// @param _hash The hash signed
    /// @param _signature The signature
    function _checkSignature(address _sender, bytes32 _hash, bytes calldata _signature)
        private
        view
        returns (bool isValid)
    {
        // Extract the signature
        SignatureLayout calldata metadata;
        assembly {
            // Extract metadata
            metadata := _signature.offset
        }

        // Ensure pub key exist here (and copy it into memory)
        WebAuthNPubKey memory pubKey = signerStorage[_sender].pubKeys[metadata.authenticatorIdHash];
        if (pubKey.x == 0 || pubKey.y == 0) {
            return false;
        }

        // If the signature is using the on-chain p256 verifier, we will use it
        address p256Verifier = P256_VERIFIER;
        if (metadata.useOnChainP256Verifier) {
            p256Verifier = WebAuthnVerifier.PRECOMPILED_P256_VERIFIER;
        }

        // Extract the first byte of the signature to check
        return WebAuthnVerifier._verifyWebAuthNSignature(p256Verifier, _hash, metadata.signature, pubKey.x, pubKey.y);
    }
}
