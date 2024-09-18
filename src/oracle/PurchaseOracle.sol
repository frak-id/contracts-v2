// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {IPurchaseOracle} from "./IPurchaseOracle.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/// @title PurchsaeOracle
/// @author @KONFeature
/// @notice Contract acting as an oracle for purchase states accross the products networks
/// @custom:security-contact contact@frak.id
contract PurchaseOracle is OwnableRoles, IPurchaseOracle {
    /// @dev Struct representing a purchase representing a simple purchase
    struct Purchase {
        // todo: should be custom type or enum
        // todo: Could be concated with user or currency
        bytes2 state;
        // User who performed the purchase
        address user;
        // Internal purchase id (could be shopify `order.id` or stripe `paymentIntent.id` for example)
        bytes32 internalId;
        // Currency amount, with 6 decimals (on uint232 so it can be stored in a bytes32 with the currency)
        uint232 amount;
        // three letter currency code matching ISO 4217 standard
        bytes3 currency;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.purchase_oracle')) - 1)
    bytes32 private constant PURCHASE_ORACLE_STORAGE_SLOT =
        0x7604630823fe740cd249174fdd8aaffc7f3bd2a8dffc7d7da7625ddeb9cbed9e;

    /// @custom:storage-location erc7201:frak.registry.referral
    struct PurchaseOracleStorage {
        /// @dev Mapping of product ids to purchase id to purchase struct
        mapping(uint256 productId => mapping(bytes32 purchaseId => Purchase)) purchases;
        /// @dev Mapping of product ids to purchase update hooks
        mapping(uint256 productId => address[]) purchaseUpdateHooks;
    }

    function _purchaseOracleStorage() private pure returns (PurchaseOracleStorage storage storagePtr) {
        assembly {
            storagePtr.slot := PURCHASE_ORACLE_STORAGE_SLOT
        }
    }
}
