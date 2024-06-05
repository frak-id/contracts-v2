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

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when an article is opened by the given `user`
    event ArticleOpened(bytes32 indexed articleId, address user);

    /// @dev Event when an article is read by the given `user`
    event ArticleRead(bytes32 indexed articleId, address user);

    /// @dev Event emitted when a `user` was referred by `referrer`
    event UserReferred(address indexed user, address indexed referrer);

    constructor(uint256 _contentId, address _referralRegistry) ContentInteraction(_contentId, _referralRegistry) {}

    /* -------------------------------------------------------------------------- */
    /*                          Open interaction methods                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Function called by a user when he openned an article
    function articleOpened(bytes32 _articleId, bytes calldata _signature) external {
        _articleOpened(_articleId, msg.sender, address(0), _signature);
    }

    /// @dev Function called by a user when he openned an article
    function articleOpened(bytes32 _articleId, address _referrer, bytes calldata _signature) external {
        _articleOpened(_articleId, msg.sender, _referrer, _signature);
    }

    /// @dev Function called when a user openned an article `_articleId` via a shared link `_shareId`
    function _articleOpened(bytes32 _articleId, address _user, address _referrer, bytes calldata _signature) private {
        // Validate the interaction
        bytes32 interactionData = keccak256(abi.encode(_OPEN_ARTICLE_INTERACTION, _articleId, _referrer));
        _validateInteraction(interactionData, _user, _signature);

        // Emit the open event and send the interaction to the campaign if needed
        {
            emit ArticleOpened(_articleId, _user);
            _sendInteractionToCampaign(InteractionEncoderLib.pressEncodeOpenArticle(_articleId, _user));
        }

        // If we got no referrer, we can just stop here
        if (_referrer == address(0)) {
            return;
        }

        // Check if the user can have a referrer on this platform
        if (_isUserAlreadyReferred(_user)) {
            // todo: maybe some retention campagn there? And so an interface with returning user?
            return;
        }

        // Emit the share link used event
        {
            emit UserReferred(_user, _referrer);
            _sendInteractionToCampaign(InteractionEncoderLib.pressEncodeReferred(_user));
        }
        // Save the info inside the right referral tree
        _saveReferrer(_user, _referrer);
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
    /*                            Some metadata reader                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the content type for the given platform
    function getContentType() public pure override returns (ContentTypes) {
        return CONTENT_TYPE_PRESS;
    }
}
