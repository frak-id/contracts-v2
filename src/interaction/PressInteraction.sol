// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {CONTENT_TYPE_PRESS, ContentTypes} from "../constants/ContentTypes.sol";
import {CAMPAIGN_MANAGER_ROLE} from "../constants/Roles.sol";
import {ContentInteraction} from "./ContentInteraction.sol";
import {InteractionEncoderLib} from "./lib/InteractionEncoderLib.sol";

/// @title PressInteraction
/// @author @KONFeature
/// @notice Contract managing a press content platform user interaction
/// @custom:security-contact contact@frak.id
contract PressInteraction is ContentInteraction {
    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev keccak256('frak.press.interaction.open_article')
    bytes32 private constant _OPEN_ARTICLE_INTERACTION =
        0xc0a24ffb7afa254ad3052f8f1da6e4268b30580018115d9c10b63352b0004b2d;

    /// @dev keccak256('frak.press.interaction.read_article')
    bytes32 private constant _READ_ARTICLE_INTERACTION =
        0xd5bd0fbe3510f2dde55a90e8bb325735d540cc475e1875f00abfd5a81015b073;

    /// @dev keccak256('frak.press.interaction.create_share_link')
    bytes32 private constant _CREATE_SHARE_LINK_INTERACTION =
        0xaf75a9c1cea9f66971d8d341459fd474beb48c11cce7f5962860bec428704d98;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when an article is opened by the given `user`
    event ArticleOpened(bytes32 indexed articleId, address user);

    /// @dev Event when an article is read by the given `user`
    event ArticleRead(bytes32 indexed articleId, address user);

    /// @dev Event emitted when a share link is created by the given `user`
    event ShareLinkCreated(bytes32 indexed articleId, address user, bytes32 shareId);

    /// @dev Event when a share link is used
    event ShareLinkUsed(bytes32 indexed shareId, address user);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.press.interaction')) - 1)
    bytes32 private constant _PRESS_INTERACTION_STORAGE_SLOT =
        0xf37141af23c6aeeb0bd5dacffe9b19ec3b801f111eab5899fcd9f42681bb538e;

    /// @dev Info about the sharing of an article
    struct PressShareInfo {
        bytes32 articleId;
        address user;
    }

    struct PressInteractionStorage {
        /// @dev Mapping of share id to article and user referring
        mapping(bytes32 shareId => PressShareInfo shareInfo) sharings;
    }

    function _storage() private pure returns (PressInteractionStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _PRESS_INTERACTION_STORAGE_SLOT
        }
    }

    constructor(uint256 _contentId, address _referralRegistry) ContentInteraction(_contentId, _referralRegistry) {}

    /* -------------------------------------------------------------------------- */
    /*                          Open interaction methods                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Function called by a user when he openned an article
    function articleOpened(bytes32 _articleId, bytes32 _shareId, bytes calldata _signature) external {
        _articleOpened(_articleId, _shareId, msg.sender, _signature);
    }

    /// @dev Function called when a user openned an article `_articleId` via a shared link `_shareId`
    function _articleOpened(bytes32 _articleId, bytes32 _shareId, address _user, bytes calldata _signature) private {
        // Validate the interaction
        bytes32 interactionData = keccak256(abi.encode(_OPEN_ARTICLE_INTERACTION, _articleId, _shareId));
        _validateInteraction(interactionData, _user, _signature);

        // Emit the open event and send the interaction to the campaign if needed
        {
            emit ArticleOpened(_articleId, _user);
            _sendInteractionToCampaign(InteractionEncoderLib.pressEncodeOpenArticle(_articleId, _user));
        }

        // If we got no share id, we can just stop here
        if (_shareId == 0) {
            return;
        }

        // Check if the sharing exist, and that it match the article id
        PressShareInfo storage shareInfo = _storage().sharings[_shareId];
        if (shareInfo.user == address(0) || shareInfo.articleId != _articleId) {
            return;
        }

        // Check if the user can have a referrer on this platform
        if (_isUserAlreadyReferred(_user)) {
            // todo: maybe some retention campagn there? And so an interface with returning user?
            return;
        }

        // Emit the share link used event
        emit ShareLinkUsed(_shareId, _user);
        // Save the info inside the right referral tree
        _saveReferrer(_user, shareInfo.user);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Article read interaction                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Function called by a user when he read an article
    function articleRead(bytes32 _articleId, bytes calldata _signature) external {
        _articleRead(_articleId, msg.sender, _signature);
    }

    /// @dev Function called when a user read an article `_articleId`
    function _articleRead(bytes32 _articleId, address _user, bytes calldata _signature) private {
        // Validate the interaction
        bytes32 interactionData = keccak256(abi.encode(_READ_ARTICLE_INTERACTION, _articleId));
        _validateInteraction(interactionData, _user, _signature);

        // Emit the read event and send the interaction to the campaign if needed
        {
            emit ArticleRead(_articleId, _user);
            _sendInteractionToCampaign(InteractionEncoderLib.pressEncodeReadArticle(_articleId, _user));
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                             Share link methods                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Function called when a user openned an article `articleId` via a shared link `shareId`
    function createShareLink(bytes32 _articleId, bytes calldata _signature) external {
        _createShareLink(_articleId, msg.sender, _signature);
    }

    /// @dev Create a new share link for the given `_articleId` and `_user`
    function _createShareLink(bytes32 _articleId, address _user, bytes calldata _signature) private {
        // Validate this interaction
        bytes32 interactionData = keccak256(abi.encode(_CREATE_SHARE_LINK_INTERACTION, _articleId));
        _validateInteraction(interactionData, _user, _signature);

        // Create the share id
        bytes32 shareId = keccak256(abi.encodePacked(_CONTENT_ID, _articleId, _user));

        // Get the current storage slot
        PressShareInfo storage shareInfo = _storage().sharings[shareId];

        // If we already got a user, directly exit
        if (shareInfo.user != address(0)) {
            return;
        }

        // Emit the read event and send the interaction to the campaign if needed
        {
            emit ShareLinkCreated(_articleId, _user, shareId);
            _sendInteractionToCampaign(InteractionEncoderLib.pressEncodeCreateShare(_articleId, _user));
        }
        // Set the right values
        shareInfo.articleId = _articleId;
        shareInfo.user = _user;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Some metadata reader                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the content type for the given platform
    function getContentType() public pure override returns (ContentTypes) {
        return CONTENT_TYPE_PRESS;
    }
}
