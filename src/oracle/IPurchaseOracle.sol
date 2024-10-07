// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @notice Enum representing possible purchase statuses
enum PurchaseStatus {
    Pending, // 0
    Completed, // 1
    Cancelled, // 2
    Refunded // 3

}

/// @title IPurchaseOracle
/// @author @KONFeature
/// @notice Interface representing a purchase oracle
/// @custom:security-contact contact@frak.id
interface IPurchaseOracle {
    /// @notice Retrieves the Merkle root for a specific product
    /// @param _productId The product ID
    /// @return merkleRoot The Merkle root associated with the product
    function getMerkleRoot(uint256 _productId) external view returns (bytes32 merkleRoot);

    /// @notice Verifies the purchase status using a Merkle proof for a specific product
    /// @param _productId The product ID
    /// @param _purchaseId The ID of the purchase
    /// @param _status The status of the purchase
    /// @param _proof The Merkle proof array
    /// @return isValid True if the proof is valid and the status is confirmed
    function verifyPurchase(uint256 _productId, uint256 _purchaseId, PurchaseStatus _status, bytes32[] calldata _proof)
        external
        view
        returns (bool isValid);
}
