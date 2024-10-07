// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, ReferralInteractions} from "../../constants/InteractionType.sol";
import {DENOMINATOR_FEATURE_REFERRAL} from "../../constants/ProductTypes.sol";
import {ReferralRegistry} from "../../registry/ReferralRegistry.sol";
import {ProductInteractionStorageLib} from "../lib/ProductInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title ReferralFeatureFacet
/// @author @KONFeature
/// @notice Contract managing the referral user interaction
/// @custom:security-contact contact@frak.id
contract ReferralFeatureFacet is ProductInteractionStorageLib, IInteractionFacet {
    using InteractionTypeLib for bytes;

    error InvalidReferrer();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a `user` created a referral link
    event ReferralLinkCreation(address user);

    /// @dev Event emitted when a `user` was referred by `referrer`
    event UserReferred(address user, address referrer);

    /// @dev The referral registry
    ReferralRegistry internal immutable REFERRAL_REGISTRY;

    constructor(ReferralRegistry _referralRegistry) {
        REFERRAL_REGISTRY = _referralRegistry;
    }

    /// @dev High level interaction router
    fallback(bytes calldata _data) external returns (bytes memory) {
        // Parse the interaction
        (InteractionType _action, bytes calldata _interactionData) = _data.unpackForFacet();

        if (_action == ReferralInteractions.REFERRED) {
            return _handleReferred(_interactionData);
        } else if (_action == ReferralInteractions.REFERRAL_LINK_CREATION) {
            return _handleReferralLinkCreation(_interactionData);
        }

        revert UnknownInteraction();
    }

    /// @dev Get the handled product type of this facet
    function productTypeDenominator() public pure override returns (uint8) {
        return DENOMINATOR_FEATURE_REFERRAL;
    }

    /* -------------------------------------------------------------------------- */
    /*                           Referral link creation                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Function called by a user when he openned an article
    function _handleReferralLinkCreation(bytes calldata _data) internal returns (bytes memory) {
        // Emit the open event and send the interaction to the campaign if needed
        emit ReferralLinkCreation(msg.sender);
        // Just resend the data
        return ReferralInteractions.REFERRAL_LINK_CREATION.packForCampaign(msg.sender, _data);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Referral interaction                            */
    /* -------------------------------------------------------------------------- */

    /// @dev The data used to refer a user
    struct ReferredData {
        address referrer;
    }

    /// @dev Function called by a user when he openned an article
    function _handleReferred(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        ReferredData calldata data;
        assembly {
            data := _data.offset
        }

        // If we got no referrer, we can just stop here
        address referrer = data.referrer;
        if (referrer == address(0)) {
            revert InvalidReferrer();
        }

        bytes32 tree = _referralTree();

        // Save the info inside the right referral tree
        // It will handle failing stuff if the user already has a referrer
        _saveReferrer(tree, msg.sender, referrer);
        // Emit the share link used event
        emit UserReferred(msg.sender, referrer);
        // Just resend the data
        return ReferralInteractions.REFERRED.packForCampaign(msg.sender, _data);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Save on the registry level that `_user` has been referred by `_referrer`
    function _saveReferrer(bytes32 tree, address _user, address _referrer) internal {
        REFERRAL_REGISTRY.saveReferrer(tree, _user, _referrer);
    }
}
