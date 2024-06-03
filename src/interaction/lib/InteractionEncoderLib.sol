// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {
    INTERACTION_PRESS_CREATE_SHARE_LINK,
    INTERACTION_PRESS_OPEN_ARTICLE,
    INTERACTION_PRESS_READ_ARTICLE,
    INTERACTION_PRESS_USED_SHARE_LINK,
    InteractionType
} from "../../constants/InteractionType.sol";

/// @author @KONFeature
/// @title InteractionEncoderLib
/// @dev Library used to encode interaction
/// @custom:security-contact contact@frak.id
library InteractionEncoderLib {
    /* -------------------------------------------------------------------------- */
    /*                           Press related encoding                           */
    /* -------------------------------------------------------------------------- */

    function pressEncodeOpenArticle(bytes32 _articleId, address _user) internal pure returns (bytes memory encoded) {
        return abi.encodePacked(InteractionType.unwrap(INTERACTION_PRESS_OPEN_ARTICLE), _articleId, _user);
    }

    function pressEncodeReadArticle(bytes32 _articleId, address _user) internal pure returns (bytes memory encoded) {
        return abi.encodePacked(InteractionType.unwrap(INTERACTION_PRESS_READ_ARTICLE), _articleId, _user);
    }

    function pressEncodeCreateShare(bytes32 _articleId, address _user) internal pure returns (bytes memory encoded) {
        return abi.encodePacked(InteractionType.unwrap(INTERACTION_PRESS_CREATE_SHARE_LINK), _articleId, _user);
    }

    function pressEncodeOpenShare(bytes32 _articleId, address _user) internal pure returns (bytes memory encoded) {
        return abi.encodePacked(InteractionType.unwrap(INTERACTION_PRESS_USED_SHARE_LINK), _articleId, _user);
    }
}
