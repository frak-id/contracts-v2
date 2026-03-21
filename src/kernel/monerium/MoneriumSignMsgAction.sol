// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @author @KONFeature
/// @title MoneriumSignMsgAction
/// @notice Kernel v2 executor (action) that emits the `SignMsg` event from the wallet address for Monerium onchain
/// signature compliance.
/// @dev This contract is called via `delegatecall` from the Kernel wallet's `fallback()`, so `address(this)` resolves
/// to the wallet address and events are emitted from the wallet.
/// @dev Register via `setExecution(selector, address(this), validator, ...)` on the Kernel wallet.
/// @dev Supports two signing modes:
///   1. `signMessage(bytes)` - Safe-compatible EIP-712 format (proven to work with Monerium)
///   2. `signMessageRaw(bytes32)` - Raw hash (for testing alternative formats)
/// @custom:security-contact contact@frak.id
contract MoneriumSignMsgAction {
    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev keccak256("SafeMessage(bytes message)") - Safe's EIP-712 message typehash
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;

    /// @dev keccak256("EIP712Domain(uint256 chainId,address verifyingContract)") - Safe's domain separator typehash
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    /// @dev bytes32(uint256(keccak256('frak.kernel.monerium.signmsg')) - 1)
    /// @dev ERC-7201 namespaced storage slot to avoid collisions with Kernel wallet storage
    uint256 private constant _SIGNED_MESSAGES_STORAGE_SLOT =
        0xf7bae0a118abf44b0ddf30fffb79978e19b0355f951a26b16e51e5552921c58e;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Monerium's required event. Emitted from the wallet address via delegatecall.
    event SignMsg(bytes32 indexed msgHash);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev When trying to sign an empty message
    error EmptyMessage();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @custom:storage-location erc7201:frak.kernel.monerium.signmsg
    struct SignedMessagesStorage {
        /// @dev Mapping of message hash to signed status (1 = signed, 0 = not signed)
        mapping(bytes32 msgHash => uint256 signed) _signedMessages;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Signing Functions                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Sign a message using Safe-compatible EIP-712 format.
    /// @dev Computes the hash following Safe's `SignMessageLib` format, stores it, and emits `SignMsg`.
    /// @dev This is the recommended method for Monerium integration since their infra was built around Safe.
    /// @param _data The raw message bytes to sign (e.g., "I hereby declare that I am the address owner.")
    function signMessage(bytes calldata _data) external {
        if (_data.length == 0) revert EmptyMessage();

        bytes32 msgHash = getMessageHash(_data);
        _getSignedMessagesStorage()._signedMessages[msgHash] = 1;
        emit SignMsg(msgHash);
    }

    /// @notice Sign a message using a raw pre-computed hash.
    /// @dev Stores the hash and emits `SignMsg`. Use this to test alternative hash formats with Monerium.
    /// @param _msgHash The pre-computed message hash to sign
    function signMessageRaw(bytes32 _msgHash) external {
        _getSignedMessagesStorage()._signedMessages[_msgHash] = 1;
        emit SignMsg(_msgHash);
    }

    /* -------------------------------------------------------------------------- */
    /*                               View Functions                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Compute the Safe-compatible EIP-712 message hash.
    /// @dev Follows Safe's `SignMessageLib.getMessageHash()` exactly:
    ///   hash = keccak256(0x19 || 0x01 || domainSeparator || keccak256(abi.encode(SAFE_MSG_TYPEHASH,
    /// keccak256(message))))
    /// @dev When called via delegatecall, `address(this)` is the wallet address, making the domain separator correct.
    /// @param _message The raw message bytes
    /// @return msgHash The EIP-712 compliant message hash
    function getMessageHash(bytes memory _message) public view returns (bytes32 msgHash) {
        msgHash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, address(this))),
                keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(_message)))
            )
        );
    }

    /// @notice Check if a message hash has been signed.
    /// @param _msgHash The message hash to check
    /// @return True if the message hash has been signed
    function isSignedMessage(bytes32 _msgHash) public view returns (bool) {
        return _getSignedMessagesStorage()._signedMessages[_msgHash] == 1;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Internal Functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the ERC-7201 namespaced storage for signed messages.
    function _getSignedMessagesStorage() private pure returns (SignedMessagesStorage storage $) {
        assembly {
            $.slot := _SIGNED_MESSAGES_STORAGE_SLOT
        }
    }
}
