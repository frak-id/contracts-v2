// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType, InteractionTypeLib, PressInteractions} from "../../constants/InteractionType.sol";
import {DENOMINATOR_PRESS} from "../../constants/ProductTypes.sol";
import {ProductInteractionStorageLib} from "../lib/ProductInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title PressInteractionFacet
/// @author @KONFeature
/// @notice Contract managing a press product platform user interaction
/// @custom:security-contact contact@frak.id
contract PressInteractionFacet is ProductInteractionStorageLib, IInteractionFacet {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when an article is opened by the given `user`
    event ArticleOpened(bytes32 indexed articleId, address user);

    /// @dev Event when an article is read by the given `user`
    event ArticleRead(bytes32 indexed articleId, address user);

    /// @dev Event emitted when a `user` was referred by `referrer`
    event UserReferred(address indexed user, address indexed referrer);

    /// @dev High level interaction router
    fallback(bytes calldata _data) external returns (bytes memory) {
        // Parse the interaction
        (InteractionType _action, bytes calldata _interactionData) = _data.unpackForFacet();

        if (_action == PressInteractions.OPEN_ARTICLE) {
            return _handleOpenArticle(_interactionData);
        } else if (_action == PressInteractions.READ_ARTICLE) {
            return _handleReadArticle(_interactionData);
        }

        revert UnknownInteraction();
    }

    /// @dev Get the handled product type of this facet
    function productTypeDenominator() public pure override returns (uint8) {
        return DENOMINATOR_PRESS;
    }

    /* -------------------------------------------------------------------------- */
    /*                          Open interaction methods                          */
    /* -------------------------------------------------------------------------- */
    /// @dev The data used to open an article
    struct OpenArticleData {
        bytes32 articleId;
    }

    /// @dev Function called by a user when he openned an article
    function _handleOpenArticle(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        OpenArticleData calldata data;
        assembly {
            data := _data.offset
        }

        // Emit the open event and send the interaction to the campaign if needed
        emit ArticleOpened(data.articleId, msg.sender);
        // Just resend the data
        return PressInteractions.OPEN_ARTICLE.packForCampaign(msg.sender, _data);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Article read interaction                          */
    /* -------------------------------------------------------------------------- */

    /// @dev The data used to open an article
    struct ReadArticleData {
        bytes32 articleId;
    }

    /// @dev Function called by a user when he openned an article
    function _handleReadArticle(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        ReadArticleData calldata data;
        assembly {
            data := _data.offset
        }

        // Emit the read event and send the interaction to the campaign if needed
        emit ArticleRead(data.articleId, msg.sender);
        // Just resend the data
        return PressInteractions.READ_ARTICLE.packForCampaign(msg.sender, _data);
    }
}
