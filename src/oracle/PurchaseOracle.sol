// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ProductAdministratorRegistry, ProductRoles} from "../registry/ProductAdministratorRegistry.sol";
import {IPurchaseOracle, PurchaseStatus} from "./IPurchaseOracle.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";

/// @author @KONFeature
/// @title PurchaseOracle
/// @notice Contract managing purchase verification using per-product Merkle roots.
/// @custom:security-contact contact@frak.id
contract PurchaseOracle is IPurchaseOracle {
    /* -------------------------------------------------------------------------- */
    /*                                    Events                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Emitted when a product's Merkle root is updated
    /// @param productId The product ID
    /// @param newMerkleRoot The new Merkle root
    event MerkleRootUpdated(uint256 indexed productId, bytes32 newMerkleRoot);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error MerkleRootNotSet();

    /* -------------------------------------------------------------------------- */
    /*                               Immutable State                              */
    /* -------------------------------------------------------------------------- */

    /// @dev The product administrator registry
    ProductAdministratorRegistry private immutable PRODUCT_ADMINISTRATOR_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Storage slot for the PurchaseOracle storage structure
    /// bytes32(uint256(keccak256('yourdomain.purchase.oracle')) - 1)
    bytes32 private constant _PURCHASE_ORACLE_STORAGE_SLOT =
        0x073848f6bc84ccc0ecb2ca2e50704da03f5aee77a333a180b76b990454311e36;

    /// @custom:storage-location erc7201:yourdomain.purchase.oracle
    struct PurchaseOracleStorage {
        /// @dev Mapping from product ID to Merkle root
        mapping(uint256 _productId => bytes32 _merkleRoot) merkleRoots;
    }

    function _purchaseOracleStorage() internal pure returns (PurchaseOracleStorage storage s) {
        bytes32 position = _PURCHASE_ORACLE_STORAGE_SLOT;
        assembly {
            s.slot := position
        }
    }

    /// @dev Constructs the PurchaseOracle contract
    /// @param _adminRegistry The address of the ProductAdministratorRegistry
    constructor(ProductAdministratorRegistry _adminRegistry) {
        PRODUCT_ADMINISTRATOR_REGISTRY = _adminRegistry;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Merkle Root Management                         */
    /* -------------------------------------------------------------------------- */

    /// @notice Updates the Merkle root for a specific product
    /// @param _productId The product ID
    /// @param _merkleRoot The new Merkle root
    function updateMerkleRoot(uint256 _productId, bytes32 _merkleRoot) external onlyOperator(_productId) {
        _purchaseOracleStorage().merkleRoots[_productId] = _merkleRoot;
        emit MerkleRootUpdated(_productId, _merkleRoot);
    }

    /// @notice Retrieves the Merkle root for a specific product
    /// @param _productId The product ID
    /// @return merkleRoot The Merkle root associated with the product
    function getMerkleRoot(uint256 _productId) external view returns (bytes32 merkleRoot) {
        merkleRoot = _purchaseOracleStorage().merkleRoots[_productId];
    }

    /* -------------------------------------------------------------------------- */
    /*                              Purchase Verification                         */
    /* -------------------------------------------------------------------------- */

    /// @notice Verifies the purchase status using a Merkle proof for a specific product
    /// @param _productId The product ID
    /// @param _purchaseId The ID of the purchase
    /// @param _status The status of the purchase
    /// @param _proof The Merkle proof array
    /// @return isValid True if the proof is valid and the status is confirmed
    function verifyPurchase(uint256 _productId, uint256 _purchaseId, PurchaseStatus _status, bytes32[] calldata _proof)
        external
        view
        returns (bool isValid)
    {
        bytes32 leaf = keccak256(abi.encodePacked(_purchaseId, _status));
        bytes32 root = _purchaseOracleStorage().merkleRoots[_productId];
        if (root == bytes32(0)) revert MerkleRootNotSet();

        isValid = MerkleProofLib.verifyCalldata(_proof, root, leaf);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Access Control Modifiers                      */
    /* -------------------------------------------------------------------------- */

    /// @dev Only allow calls from an authorized operator for the given product
    /// @param _productId The product ID
    modifier onlyOperator(uint256 _productId) {
        PRODUCT_ADMINISTRATOR_REGISTRY.onlyAllRolesOrAdmin(
            _productId, msg.sender, ProductRoles.PURCHASE_ORACLE_OPERATOR_ROLE
        );
        _;
    }
}
