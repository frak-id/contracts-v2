// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentInteraction, PlatformMetadata} from "./ContentInteraction.sol";
import {CAMPAIGN_MANAGER_ROLES} from "../constants/Roles.sol";
import {CONTENT_TYPE_PRESS} from "../constants/Contents.sol";

/// @title PressInteraction
/// @author @KONFeature
/// @notice Interface for a press type content
/// @custom:security-contact contact@frak.id
contract PressInteraction is ContentInteraction {
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when an article is opened by the given `user`
    event ArticleOpened(bytes32 indexed articleId, address indexed user);

    /// @dev Event when a share link is used
    event ShareLinkUsed(bytes32 indexed shareId, address indexed user);

    /// @dev Event emitted when a share link is created by the given `user`
    event ShareLinkCreated(bytes32 indexed articleId, address indexed user, bytes32 shareId);

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

    constructor(uint256 _contentId, address _owner, address _referralRegistry)
        ContentInteraction(_contentId, _owner, _referralRegistry)
    {
        // _setRoles(_owner, CAMPAIGN_MANAGER_ROLES);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Open interaction methods                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Function called by a user when he openned an article
    function articleOpened(bytes32 _articleId, bytes32 _shareId) external {
        _articleOpened(_articleId, _shareId, msg.sender);
    }

    /// @dev Function called when a user openned an article `_articleId` via a shared link `_shareId`
    function _articleOpened(bytes32 _articleId, bytes32 _shareId, address _user) private {
        // Emit the open event
        emit ArticleOpened(_articleId, _user);

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
    /*                             Share link methods                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Function called when a user openned an article `articleId` via a shared link `shareId`
    function createShareLink(bytes32 _articleId) external {
        _createShareLink(_articleId, msg.sender);
    }

    /// @dev Create a new share link for the given `_articleId` and `_user`
    function _createShareLink(bytes32 _articleId, address _user) private {
        // Create the share id
        bytes32 shareId = keccak256(abi.encodePacked(_CONTENT_ID, _articleId, _user));

        // Get the current storage slot
        PressShareInfo storage shareInfo = _storage().sharings[shareId];

        // If we already got a user, directly exit
        if (shareInfo.user != address(0)) {
            return;
        }

        // Otherwise, emit the event and set the right values
        emit ShareLinkCreated(_articleId, _user, shareId);
        shareInfo.articleId = _articleId;
        shareInfo.user = _user;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Some metadata reader                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the content type for the given platform
    function getContentType() public pure override returns (bytes4) {
        return CONTENT_TYPE_PRESS;
    }

    /// @dev Get all the platform metadata
    function getMetadata() external pure override returns (PlatformMetadata memory) {
        return PlatformMetadata({
            contentType: CONTENT_TYPE_PRESS,
            platformName: "Press",
            platformOrigin: "Press",
            originHash: keccak256("Press")
        });
    }
}
