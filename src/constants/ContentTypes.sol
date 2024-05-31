// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev Global type for a bytes32 olding multiple content types
type ContentTypes is bytes32;

using ContentTypesLib for ContentTypes global;

/// @dev Set of helper functions for content types
library ContentTypesLib {
    function isEmpty(ContentTypes self) internal pure returns (bool isType) {
        return ContentTypes.unwrap(self) == 0;
    }

    function isDappType(ContentTypes self) internal pure returns (bool isType) {
        return self.containType(CONTENT_TYPE_DAPP);
    }

    function isPressType(ContentTypes self) internal pure returns (bool isType) {
        return self.containType(CONTENT_TYPE_PRESS);
    }

    function containType(ContentTypes self, ContentTypes typeToCheck) internal pure returns (bool containsType) {
        return ContentTypes.unwrap(self) & ContentTypes.unwrap(typeToCheck) != 0;
    }
}

/* -------------------------------------------------------------------------- */
/*                          All of our content types                          */
/* -------------------------------------------------------------------------- */

ContentTypes constant CONTENT_TYPE_DAPP = ContentTypes.wrap(bytes32(uint256(1 << 0)));
ContentTypes constant CONTENT_TYPE_PRESS = ContentTypes.wrap(bytes32(uint256(1 << 1)));
