// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author @KONFeature
/// @title MultiWebAuthNSignatureLib
/// @notice This contract is used to help us with the manipulation of the webauthn signature
/// @custom:security-contact contact@frak.id
library MultiWebAuthNSignatureLib {
    /// @dev Here is how the bytes chain is formed
    /// The chain of byte is as follow:
    /// - 0 -> Use on chain p256 or not
    /// - 1-33 -> authenticator id to use
    /// - 34-66 -> challenge offset
    /// - 67-99 -> r
    /// - 131 -> s
    /// - 132-134 -> authDataLength -> ADL
    /// - 135-137 -> clientDataLEngth -> CDL
    /// - 138-(138+ADL) -> authData
    /// - (138+ADL)-(138+ADL+CDL) -> clientData

    /// @dev Check if we want to use onchain p256 or not
    function useOnChainP256(bytes calldata _self) internal pure returns (bool useNativeP256) {
        assembly {
            // Copy the use onchain part in the free mem pointer
            useNativeP256 := shr(248, calldataload(_self.offset))
        }
    }

    /// @dev Extract the authenticator id from the signature received
    function authenticatorId(bytes calldata _self) internal pure returns (bytes32 _authenticatorId) {
        assembly {
            _authenticatorId := calldataload(add(_self.offset, 1))
        }
    }

    /// @dev Extract the raw signature bytes
    function getSignatureBytes(bytes calldata _self) internal pure returns (bytes calldata _signature) {
        assembly {
            // Extract the whole 32 bytes of value
            _signature.offset := add(_self.offset, 0x21)
            _signature.length := sub(_self.length, 0x21)
        }
    }
}
