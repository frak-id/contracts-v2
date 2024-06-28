// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.23;

import {RLPReader} from "rlp/RLPReader.sol";

/// Extracted from Cometh MPT implementation: https://github.com/cometh-hq/pixel-war/blob/aab5061fb4113b31a7f00b4a7ce32c3dbbc3cd4d/packages/contracts/src/libs/MPT.sol
/// Modification:
///  - Only keeping EIP-1186 compliant proof check
///  - Some gas optimisations
library MPT {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    error InvalidProof(uint256 index);
    error InvalidAccount();

    /// @dev Verify an account proof for the storage root
    /// @dev format [nonce,balance,storageRoot,codeHash]
    function verifyAccountStorage(address account, bytes32 root, uint256 storageRoot, bytes[] calldata proof)
        internal
        pure
        returns (bool)
    {
        uint256 key = uint256(keccak256(abi.encodePacked(account)));

        bytes memory leaf = verifyLeaf(root, key, proof);

        RLPReader.RLPItem[] memory decoded = leaf.toRlpItem().toList();

        if (decoded.length != 4) revert InvalidAccount();
        if (decoded[2].toUint() != storageRoot) return false;

        return true;
    }

    /// @dev Verify a storage proof, and return it's value
    function verifyAndGetStorageSlot(bytes32 root, uint256 slot, bytes[] calldata proof)
        internal
        pure
        returns (uint256)
    {
        uint256 key = uint256(keccak256(abi.encode(slot)));
        bytes memory leaf = verifyLeaf(root, key, proof);
        return leaf.toRlpItem().toUint();
    }

    /// @dev Verify a leaf in a MPT tree
    function verifyLeaf(bytes32 root, uint256 key, bytes[] calldata proof)
        internal
        pure
        returns (bytes memory result)
    {
        uint256 nibble = 0;
        RLPReader.RLPItem[] memory node;
        for (uint256 index = 0; index < proof.length; ++index) {
            if (keccak256(proof[index]) != root) revert InvalidProof(index);

            node = proof[index].toRlpItem().toList();
            if (node.length == 17) {
                uint256 keyNibble = (key >> (252 - (nibble++ * 4))) & 0xf;
                root = bytes32(node[keyNibble].toUintStrict());
            } else if (node.length == 2) {
                bytes memory prefix = node[0].toBytes();

                bool isExtension;
                (isExtension, nibble) = checkEncodedPath(prefix, key, nibble, index);

                if (isExtension) {
                    root = bytes32(node[1].toUintStrict());
                } else {
                    break;
                }
            }
        }

        if (nibble != 64) revert InvalidProof(proof.length - 1);
        return node[1].toBytes();
    }

    /*
        hex char    bits    |    node type partial     path length
      ----------------------------------------------------------
        0        0000    |       extension              even
        1        0001    |       extension              odd
        3        0011    |   terminating (leaf)         odd
        2        0010    |   terminating (leaf)         even
    */
    function checkEncodedPath(bytes memory prefix, uint256 key, uint256 nibble, uint256 index)
        private
        pure
        returns (bool, uint256)
    {
        uint8 nodeType = uint8(prefix[0] >> 4);

        // odd cases
        if (nodeType & 0x1 != 0) {
            uint256 keyNibble = (key >> (252 - (nibble++ * 4))) & 0xf;

            uint256 prefixNibble = uint8(prefix[0]) & 0xf;
            if (prefixNibble != keyNibble) revert InvalidProof(index);
        }

        uint256 prefixLen = prefix.length;

        assert(nibble % 2 == 0);
        for (uint256 i = 1; i < prefixLen; ++i) {
            uint256 prefixByte = uint8(prefix[i]);
            uint256 keyByte = (key >> (248 - (nibble * 4))) & 0xff;

            if (prefixByte != keyByte) revert InvalidProof(index);

            nibble += 2;
        }

        // return true if node is an extension and we should continue traveling the trie
        // also returns the new nibble count, for bookkeeping
        return (nodeType & 0x2 == 0, nibble);
    }
}
