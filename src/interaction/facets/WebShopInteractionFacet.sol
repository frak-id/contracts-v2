// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, WebShopInteractions} from "../../constants/InteractionType.sol";
import {DENOMINATOR_WEB_SHOP} from "../../constants/ProductTypes.sol";
import {ProductInteractionStorageLib} from "../lib/ProductInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title WebShopInteractionFacet
/// @author @KONFeature
/// @notice Contract managing a web shop platform user interaction
/// @custom:security-contact contact@frak.id
contract WebShopInteractionFacet is ProductInteractionStorageLib, IInteractionFacet {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when a webshop is openned by the given `user`
    event WebShopOpenned(address user);

    /// @dev High level interaction router
    fallback(bytes calldata _data) external returns (bytes memory) {
        // Parse the interaction
        (InteractionType _action,) = _data.unpackForFacet();

        if (_action == WebShopInteractions.OPEN) {
            emit WebShopOpenned(msg.sender);
            // Just resend the data for campaign managment
            return WebShopInteractions.OPEN.packForCampaign(msg.sender);
        }

        revert UnknownInteraction();
    }

    /// @dev Get the handled product type of this facet
    function productTypeDenominator() public pure override returns (uint8) {
        return DENOMINATOR_WEB_SHOP;
    }
}
