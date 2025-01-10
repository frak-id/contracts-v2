// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, RetailInteractions} from "../../constants/InteractionType.sol";
import {DENOMINATOR_RETAIL} from "../../constants/ProductTypes.sol";
import {ProductInteractionStorageLib} from "../lib/ProductInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title RetailInteractionFacet
/// @author @KONFeature
/// @notice Contract managing a retail related user interaction
/// @custom:security-contact contact@frak.id
contract RetailInteractionFacet is ProductInteractionStorageLib, IInteractionFacet {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event a `user` has proceed to a customer meeting in the `agencyId`
    event CustomerMeeting(bytes32 agencyId, address user);

    /// @dev High level interaction router
    fallback(bytes calldata _data) external returns (bytes memory) {
        // Parse the interaction
        (InteractionType _action, bytes calldata _interactionData) = _data.unpackForFacet();

        if (_action == RetailInteractions.CUSTOMER_MEETING) {
            return _handleCustomerMeeting(_interactionData);
        }

        revert UnknownInteraction();
    }

    /// @dev Get the handled product type of this facet
    function productTypeDenominator() public pure override returns (uint8) {
        return DENOMINATOR_RETAIL;
    }

    /* -------------------------------------------------------------------------- */
    /*                           Custom meetings methods                          */
    /* -------------------------------------------------------------------------- */

    /// @dev The data used to open an article
    struct CustomerMeetingData {
        bytes32 agencyId;
    }

    /// @dev Function called by a user when he openned an article
    function _handleCustomerMeeting(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        CustomerMeetingData calldata data;
        assembly {
            data := _data.offset
        }

        // Emit the open event and send the interaction to the campaign if needed
        emit CustomerMeeting(data.agencyId, msg.sender);
        // Just resend the data
        return RetailInteractions.CUSTOMER_MEETING.packForCampaign(msg.sender, _data);
    }
}
