// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author @KONFeature
/// @title WebAuthNSignatureLib
/// @notice This contract is used to help us with the manipulation of the webauthn signature
/// @custom:security-contact contact@frak.id
library WebAuthNSignatureLib {
    /// @dev Here is how the bytes chain is formed
    /// The chain of byte is as follow:
    /// - 0-32 -> challenge offset
    /// - 33-64 -> r
    /// - 65-96 -> s
    /// - 97-99 -> authDataLength -> ADL
    /// - 100-102 -> clientDataLEngth -> CDL
    /// - 103-(103+ADL) -> authData
    /// - (103+ADL)-(103+ADL+CDL) -> clientData

    /// @dev Extract the authenticator id from the signature received
    function getR(bytes calldata _self) internal pure returns (uint256 _r) {
        assembly {
            _r := calldataload(add(_self.offset, 0x20))
        }
    }

    /// @dev Extract the authenticator id from the signature received
    function getS(bytes calldata _self) internal pure returns (uint256 _s) {
        assembly {
            _s := calldataload(add(_self.offset, 0x40))
        }
    }

    /// @dev Extract the authenticator id from the signature received
    function formattingPayload(bytes calldata _self)
        internal
        pure
        returns (uint256 _challangeOffset, bytes calldata _authData, bytes calldata _clientData)
    {
        assembly {
            // Extract the whole 32 bytes of value
            _challangeOffset := calldataload(_self.offset)
            // Extract authData length (from 0x20 to 0x23)
            let allLengths := calldataload(add(_self.offset, 0x60))
            // The 3 first bytes of allLengths are the authData length
            let authDataLength := shr(232, allLengths)
            let clientDataLength := and(shr(208, allLengths), 0x000FFF)
            // Then load the auth data array
            _authData.offset := add(_self.offset, 0x66)
            _authData.length := authDataLength
            // And then the client data array
            _clientData.offset := add(_authData.offset, authDataLength)
            _clientData.length := clientDataLength
        }
    }
}
