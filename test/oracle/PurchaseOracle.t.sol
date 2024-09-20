// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import {Merkle} from "lib/murky/src/Merkle.sol";
import {PRODUCT_TYPE_PRESS} from "src/constants/ProductTypes.sol";
import {PURCHASE_ORACLE_OPERATOR_ROLE} from "src/constants/Roles.sol";
import {PurchaseStatus} from "src/oracle/IPurchaseOracle.sol";
import {PurchaseOracle} from "src/oracle/PurchaseOracle.sol";

contract PurchaseOracleTest is EcosystemAwareTest {
    address internal oracleOperator = makeAddr("oracleOperator");

    uint256 productId;

    /// Murky merkle helper
    Merkle m = new Merkle();

    function setUp() public {
        _initEcosystemAwareTest();

        // Setup a random product
        productId = _mintProduct(PRODUCT_TYPE_PRESS, "name", "random-domain");

        // Grant the right roles to the purchase oracle
        vm.prank(productOwner);
        adminRegistry.grantRoles(productId, oracleOperator, PURCHASE_ORACLE_OPERATOR_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Updating merkle root test                         */
    /* -------------------------------------------------------------------------- */

    function test_updateMerkleRoot_Unauthorized() public {
        vm.expectRevert(PurchaseOracle.Unauthorized.selector);
        purchaseOracle.updateMerkleRoot(productId, "0xdeadbeef");
    }

    function test_updateMerkleRoot() public {
        vm.prank(oracleOperator);
        purchaseOracle.updateMerkleRoot(productId, "0xdeadbeef");

        assertEq(purchaseOracle.getMerkleRoot(productId), "0xdeadbeef");
    }

    function test_updateMerkleRoot_toZero() public {
        vm.prank(oracleOperator);
        purchaseOracle.updateMerkleRoot(productId, bytes32(0));

        assertEq(purchaseOracle.getMerkleRoot(productId), bytes32(0));
    }

    function testFuzz_updateMerkleRoot(bytes32 root) public {
        vm.prank(oracleOperator);
        purchaseOracle.updateMerkleRoot(productId, root);

        assertEq(purchaseOracle.getMerkleRoot(productId), root);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Purchase verification                           */
    /* -------------------------------------------------------------------------- */

    function test_verifyPurchase_MerkleRootNotSet() public {
        // Update the merkle root
        bytes32[] memory proof = new bytes32[](0);

        // Verify the purchase
        vm.expectRevert(PurchaseOracle.MerkleRootNotSet.selector);
        purchaseOracle.verifyPurchase(productId, 0, PurchaseStatus.Pending, proof);
    }

    function test_verifyPurchase() public {
        // Generate a merkle tree and proof
        (bytes32 root, bytes32[] memory proof) = _generateMekleTreeAndProof(0, PurchaseStatus.Pending);

        // Update the merkle root
        vm.prank(oracleOperator);
        purchaseOracle.updateMerkleRoot(productId, root);

        // Verify the purchase
        assertEq(purchaseOracle.verifyPurchase(productId, 0, PurchaseStatus.Pending, proof), true);
    }

    function testFuzz_verifyPurchase(uint256 purchaseId) public {
        // Generate a merkle tree and proof
        (bytes32 root, bytes32[] memory proof) = _generateMekleTreeAndProof(purchaseId, PurchaseStatus.Pending);

        // Update the merkle root
        vm.prank(oracleOperator);
        purchaseOracle.updateMerkleRoot(productId, root);

        // Verify the purchase
        assertEq(purchaseOracle.verifyPurchase(productId, purchaseId, PurchaseStatus.Pending, proof), true);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function _generateMekleTreeAndProof(uint256 _purchaseId, PurchaseStatus _status)
        internal
        returns (bytes32 root, bytes32[] memory proof)
    {
        vm.pauseGasMetering();

        // data that will be used for the merklee tree
        bytes32[] memory data = new bytes32[](10);

        // Create 9 random leafs
        for (uint256 i = 0; i < 9; i++) {
            data[i] = keccak256(abi.encodePacked(i));
        }

        // Finally insert the leaf we want
        bytes32 leaf = keccak256(abi.encodePacked(_purchaseId, _status));
        data[9] = leaf;

        // Generate the tree
        root = m.getRoot(data);
        proof = m.getProof(data, 9);

        vm.resetGasMetering();
    }

    function test_generateMekleTreeAndProof() public {
        (bytes32 root, bytes32[] memory proof) = _generateMekleTreeAndProof(0, PurchaseStatus.Pending);

        bytes32 leaf = keccak256(abi.encodePacked(bytes32(0), PurchaseStatus.Pending));
        assertEq(m.verifyProof(root, proof, leaf), true);
    }
}
