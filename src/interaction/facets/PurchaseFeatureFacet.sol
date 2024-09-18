// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, PurchaseInteractions} from "../../constants/InteractionType.sol";
import {DENOMINATOR_FEATURE_PURCHASE} from "../../constants/ProductTypes.sol";

import {IPurchaseOracle} from "../../oracle/IPurchaseOracle.sol";
import {ProductInteractionStorageLib} from "../lib/ProductInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title PurchaseFeatureFacet
/// @author @KONFeature
/// @notice Contract managing a purchase related user interaction
/// @custom:security-contact contact@frak.id
contract PurchaseFeatureFacet is ProductInteractionStorageLib, IInteractionFacet {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when purchase is started by the given `user`
    event PurchaseStarted(bytes32 indexed purchaseId, address user);

    /// @dev The purchase oracle
    IPurchaseOracle internal immutable PURCHASE_ORACLE;

    constructor(IPurchaseOracle _purchaseOracle) {
        PURCHASE_ORACLE = _purchaseOracle;
    }

    /// @dev High level interaction router
    fallback(bytes calldata _data) external returns (bytes memory) {
        // Parse the interaction
        (InteractionType _action, bytes calldata _interactionData) = _data.unpackForFacet();

        if (_action == PurchaseInteractions.PURCHASE_STARTED) {
            return _handleStartPurchase(_interactionData);
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
    struct StartPurchaseData {
        bytes32 purchaseId;
    }

    /// @dev Function called by a user when he start a purchase
    function _handleStartPurchase(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        StartPurchaseData calldata data;
        assembly {
            data := _data.offset
        }

        // Emit the purchase start event
        emit PurchaseStarted(data.purchaseId, msg.sender);
        // Just resend the data
        return PurchaseInteractions.PURCHASE_STARTED.packForCampaign(msg.sender, _data);
    }
}
