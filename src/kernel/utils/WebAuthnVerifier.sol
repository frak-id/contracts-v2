// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Base64} from "solady/utils/Base64.sol";
import {WebAuthNSignatureLib} from "../types/WebAuthNSignatureLib.sol";

/// @title WebAuthnVerifier
/// @author KONFeature
/// @notice A library used to format webauthn stuff into verifiable p256 messages msg
/// From https://github.com/cometh-hq/p256-signer/blob/09319213276da69aad6d96fa75cd339726f78bb9/contracts/P256Signer.sol
/// And https://github.com/rdubois-crypto/FreshCryptoLib/blob/master/solidity/src/FCL_Webauthn.sol
library WebAuthnVerifier {
    using WebAuthNSignatureLib for bytes;

    /// @dev Error thrown when the webauthn data is invalid
    error InvalidWebAuthNData();

    /// @dev 'bytes4(keccak256("InvalidWebAuthNData()"))'
    uint256 private constant _INVALID_WEBAUTHN_DATA_SELECTOR = 0x81177746;

    /// @dev the data flag mask we will use to verify the signature
    /// @dev Always 0x01 for user presence flag -> https://www.w3.org/TR/webauthn-2/#concept-user-present
    bytes1 private constant AUTHENTICATOR_DATA_FLAG_MASK = 0x01;

    /// @dev The address of the pre-compiled p256 verifier contract (following RIP-7212)
    address internal constant PRECOMPILED_P256_VERIFIER = address(0x100);

    /// @dev Format the webauthn challenge into a p256 message
    /// @dev return the raw message that has been signed by the user on the p256 curve
    /// @dev Logic from https://github.com/rdubois-crypto/FreshCryptoLib/blob/master/solidity/src/FCL_Webauthn.sol
    /// @param _hash The hash that has been signed via WebAuthN
    /// @param _signature The signature that has been provided with the userOp
    /// @return p256Message The message that has been signed on the p256 curve
    function _formatWebAuthNChallenge(bytes32 _hash, bytes calldata _signature)
        internal
        pure
        returns (bytes32 p256Message)
    {
        // Extract a few calldata pointer we will use to format / verify our msg
        (uint256 challengeOffset, bytes calldata authenticatorData, bytes calldata clientData) =
            _signature.formattingPayload();

        // If the challenge offset is uint256 max, it's mean that we are in the case of a dummy sig, so we can skip the check and just return the hash
        if (challengeOffset == type(uint256).max) {
            return _hash;
        }

        // Otherwise, perform the complete format and checks of the data
        {
            // Let the caller check if User Presence (0x01) or User Verification (0x04) are set
            if ((authenticatorData[32] & AUTHENTICATOR_DATA_FLAG_MASK) != AUTHENTICATOR_DATA_FLAG_MASK) {
                revert InvalidWebAuthNData();
            }
            // Verify that clientData commits to the expected client challenge
            // Use the Base64Url encoding which omits padding characters to match WebAuthn Specification
            bytes memory challengeEncoded = bytes(Base64.encode(abi.encodePacked(_hash), true, true));

            // The part that will old the challenge extracted from the clientData
            bytes memory challengeExtracted = new bytes(challengeEncoded.length);

            assembly {
                // Extract the challenge from the clientData
                calldatacopy(
                    add(challengeExtracted, 32), add(clientData.offset, challengeOffset), mload(challengeExtracted)
                )

                // Check that the challenge extracted from the clientData is the same as the one provided in the userOp
                if iszero(
                    eq(
                        // Hash of the challenge exracted from the `clientData`
                        keccak256(add(challengeExtracted, 32), mload(challengeExtracted)),
                        // Hash of the provided challenge, encoded in Base64Url (to match the clientData encoding)
                        keccak256(add(challengeEncoded, 32), mload(challengeEncoded))
                    )
                ) {
                    mstore(0x00, _INVALID_WEBAUTHN_DATA_SELECTOR)
                    revert(0x1c, 0x04)
                }
            }
        }

        // Verify the signature over sha256(authenticatorData || sha256(clientData))
        bytes memory verifyData = new bytes(authenticatorData.length + 32);

        assembly {
            // Add the authenticator data at the start of the verifyData
            calldatacopy(add(verifyData, 32), authenticatorData.offset, authenticatorData.length)
        }

        bytes32 clientDataHashed = sha256(clientData);
        assembly {
            // Add the client data hash at the end of the verifyData
            mstore(add(verifyData, add(authenticatorData.length, 32)), clientDataHashed)
        }

        // Return the sha256 of the verifyData
        return sha256(verifyData);
    }

    /// @dev Proceed to the full webauth verification
    /// @param _p256Verifier The p256 verifier contract on-chain (if user want to use this instead of the precompiled one)
    /// @param _hash The hash that has been signed via WebAuthN
    /// @param _signature The signature that has been provided with the userOp
    /// @param _x The X point of the public key
    /// @param _y The Y point of the public key
    /// @return isValid True if the signature is valid, false otherwise
    function _verifyWebAuthNSignature(
        address _p256Verifier,
        bytes32 _hash,
        bytes calldata _signature,
        uint256 _x,
        uint256 _y
    ) internal view returns (bool isValid) {
        // Format the webauthn challenge into a p256 message
        bytes32 challenge = _formatWebAuthNChallenge(_hash, _signature);

        // Prepare the argument we will use to verify the signature
        bytes memory args = abi.encode(challenge, _signature.getR(), _signature.getS(), _x, _y);

        // Send the call the the p256 verifier
        (bool success, bytes memory ret) = _p256Verifier.staticcall(args);
        // If empty ret, return false
        if (success == false || ret.length == 0) {
            return false;
        }

        // Ensure that it has returned 1
        return abi.decode(ret, (uint256)) == 1;
    }
}
