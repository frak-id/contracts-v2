// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, PurchaseInteractions} from "../../constants/InteractionType.sol";
import {DENOMINATOR_FEATURE_PURCHASE} from "../../constants/ProductTypes.sol";
import {IPurchaseOracle, PurchaseStatus} from "../../oracle/IPurchaseOracle.sol";
import {ProductInteractionStorageLib} from "../lib/ProductInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title PurchaseFeatureFacet
/// @author @KONFeature
/// @notice Contract managing a purchase related user interaction
/// @custom:security-contact contact@frak.id
contract PurchaseFeatureFacet is ProductInteractionStorageLib, IInteractionFacet {
    using InteractionTypeLib for bytes;

    error PurchaseNotCompleted();
    error PurchaseAlreadyProcessed();

    /// @dev 'bytes4(keccak256("PurchaseAlreadyProcessed()"))'
    uint256 private constant _PURCHASED_ALREADY_STARTED_SELECTOR = 0x43bc8dc8;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when purchase is started by the given `user`
    event PurchaseStarted(uint256 purchaseId, address user);

    /// @dev Event when purchase is completed by the given `user`
    event PurchaseCompleted(uint256 purchaseId, address user);

    /// @dev The purchase oracle
    IPurchaseOracle internal immutable PURCHASE_ORACLE;

    /// @dev Seed for computing unique storage slots
    /// @dev `bytes4(keccak256("frak.interaction.purchase.processed"))`
    bytes4 private constant PURCHASE_PROCESSED_SEED = 0x2a6ea8f1;

    constructor(IPurchaseOracle _purchaseOracle) {
        PURCHASE_ORACLE = _purchaseOracle;
    }

    /// @dev High level interaction router
    fallback(bytes calldata _data) external returns (bytes memory) {
        // Parse the interaction
        (InteractionType _action, bytes calldata _interactionData) = _data.unpackForFacet();

        if (_action == PurchaseInteractions.PURCHASE_STARTED) {
            return _handlePurchaseStarted(_interactionData);
        } else if (_action == PurchaseInteractions.PURCHASE_COMPLETED) {
            return _handlePurchaseCompleted(_interactionData);
        }

        revert UnknownInteraction();
    }

    /// @dev Get the handled product type of this facet
    function productTypeDenominator() public pure override returns (uint8) {
        return DENOMINATOR_FEATURE_PURCHASE;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Start purchase method                           */
    /* -------------------------------------------------------------------------- */
    /// @dev The data used for a purchase start process
    struct PurchaseStartedData {
        uint256 purchaseId;
    }

    /// @dev Function called by a user when he start a purchase
    function _handlePurchaseStarted(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        PurchaseStartedData calldata data;
        assembly {
            data := _data.offset
        }

        // Emit the purchase start event
        emit PurchaseStarted(data.purchaseId, msg.sender);
        // Just resend the data
        return PurchaseInteractions.PURCHASE_STARTED.packForCampaign(msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Purchase completion                            */
    /* -------------------------------------------------------------------------- */

    /// @dev The data used for a purchase start process
    /// @dev Not rly sensitive data, just the purchase ID
    struct PurchseCompletedData {
        uint256 purchaseId;
        bytes32[] proof;
    }

    /// @dev Function for when a purchase is completed
    function _handlePurchaseCompleted(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        PurchseCompletedData calldata data;
        assembly {
            data := _data.offset
        }

        // Ensure the purchase is not already processed
        _ensureNotAlreadyPurchased(data.purchaseId);

        // Check against the oracle for the completion
        if (!PURCHASE_ORACLE.verifyPurchase(_productId(), data.purchaseId, PurchaseStatus.Completed, data.proof)) {
            // If not completed, throw an error
            revert PurchaseNotCompleted();
        }

        // Emit the purchase start event
        emit PurchaseCompleted(data.purchaseId, msg.sender);
        // Just resend the data, in a lightweight variant, triming proof etc to lighten the flow
        return PurchaseInteractions.PURCHASE_STARTED.packForCampaign(msg.sender);
    }

    /// @dev Ensure the purchase is not already processed for a given user
    function _ensureNotAlreadyPurchased(uint256 _purchaseId) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // keccak(and(msg.sender, seed), purchaseId)
            mstore(0, or(caller(), PURCHASE_PROCESSED_SEED))
            mstore(0x20, _purchaseId)

            // Compute the storage slot
            let storageSlot := keccak256(0, 0x40)

            // If already processed, revert
            if sload(storageSlot) {
                // Revert with custom error PurchaseAlreadyProcessed()
                mstore(0x00, _PURCHASED_ALREADY_STARTED_SELECTOR) // keccak256("PurchaseAlreadyProcessed()")[:4]
                revert(0x1c, 0x04)
            }

            // Mark as processed by storing 1
            sstore(storageSlot, 1)
        }
    }
}
