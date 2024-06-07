// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {CONTENT_TYPE_PRESS, DENOMINATOR_PRESS} from "../../constants/ContentTypes.sol";
import {InteractionType, InteractionTypeLib, PressInteractions} from "../../constants/InteractionType.sol";
import {CAMPAIGN_MANAGER_ROLE} from "../../constants/Roles.sol";
import {ReferralRegistry} from "../../registry/ReferralRegistry.sol";
import {ContentInteractionStorageLib} from "../lib/ContentInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title PressInteractionFacet
/// @author @KONFeature
/// @notice Contract managing a press content platform user interaction
/// @custom:security-contact contact@frak.id
contract PressInteractionFacet is ContentInteractionStorageLib, IInteractionFacet {
    error UnknownInteraction();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when an article is opened by the given `user`
    event ArticleOpened(bytes32 indexed articleId, address user);

    /// @dev Event when an article is read by the given `user`
    event ArticleRead(bytes32 indexed articleId, address user);

    /// @dev Event emitted when a `user` was referred by `referrer`
    event UserReferred(address indexed user, address indexed referrer);

    /// @dev The referral registry
    ReferralRegistry internal immutable _REFERRAL_REGISTRY;

    constructor(ReferralRegistry _referralRegistry) {
        _REFERRAL_REGISTRY = _referralRegistry;
    }

    /// @dev High level interaction router
    function receiveInteraction(InteractionType _action, bytes calldata _interactionData)
        public
        override
        returns (bytes memory)
    {
        if (_action == PressInteractions.OPEN_ARTICLE) {
            return _handleOpenArticle(_interactionData);
        } else if (_action == PressInteractions.READ_ARTICLE) {
            return _handleReadArticle(_interactionData);
        } else if (_action == PressInteractions.REFERRED) {
            return _handleReferred(_interactionData);
        }

        revert UnknownInteraction();
    }

    /// @dev Get the handled content type of this facet
    function contentTypeDenominator() public pure override returns (uint8) {
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
        {
            emit ArticleOpened(data.articleId, msg.sender);
            // todo: _sendInteractionToCampaign(InteractionEncoderLib.pressEncodeOpenArticle(_articleId, _user));
        }
        // Just resend the data
        return InteractionTypeLib.packInteractionForCampaign(PressInteractions.OPEN_ARTICLE, msg.sender, _data);
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
        {
            emit ArticleRead(data.articleId, msg.sender);
            // todo: _sendInteractionToCampaign(InteractionEncoderLib.pressEncodeReadArticle(_articleId, _user));
        }
        // Just resend the data
        return InteractionTypeLib.packInteractionForCampaign(PressInteractions.READ_ARTICLE, msg.sender, _data);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Referral interaction                            */
    /* -------------------------------------------------------------------------- */

    /// @dev The data used to open an article
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
            return "";
        }

        bytes32 tree = _referralTree();
        address user = msg.sender;

        // Check if the user can have a referrer on this platform
        if (_isUserAlreadyReferred(tree, user)) {
            // todo: maybe some retention campagn there? And so an interface with returning user?
            return "";
        }

        // Save the info inside the right referral tree
        _saveReferrer(tree, user, referrer);
        // Emit the share link used event
        {
            emit UserReferred(user, referrer);
            // todo: _sendInteractionToCampaign(InteractionEncoderLib.pressEncodeReferred(_user));
        }
        // Just resend the data
        return InteractionTypeLib.packInteractionForCampaign(PressInteractions.REFERRED, msg.sender, _data);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Save on the registry level that `_user` has been referred by `_referrer`
    function _saveReferrer(bytes32 tree, address _user, address _referrer) internal {
        _REFERRAL_REGISTRY.saveReferrer(tree, _user, _referrer);
    }

    /// @dev Check on the registry if the `_user` has already a referrer
    function _isUserAlreadyReferred(bytes32 tree, address _user) internal view returns (bool) {
        return _REFERRAL_REGISTRY.getReferrer(tree, _user) != address(0);
    }
}
