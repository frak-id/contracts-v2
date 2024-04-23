// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author @KONFeature
/// @title SingleWebAuthNSignatureLib
/// @notice This contract is used to help us with the manipulation of the webauthn signature
/// @custom:security-contact contact@frak.id
library SingleWebAuthNSignatureLib {
    /// @dev Check if we want to use onchain p256 or not
    function useOnChainP256(bytes calldata _self) internal pure returns (bool useNativeP256) {
        assembly {
            // Copy the use onchain part in the free mem pointer
            useNativeP256 := shr(248, calldataload(_self.offset))
        }
    }

    /// @dev Extract the raw signature bytes
    function getSignatureBytes(bytes calldata _self) internal pure returns (bytes calldata _signature) {
        assembly {
            // Extract the whole 32 bytes of value
            _signature.offset := add(_self.offset, 1)
            _signature.length := sub(_self.length, 1)
        }
    }
}
