// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev Global type for a bytes32 olding multiple content types
type ContentTypes is uint256;

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

    /// @dev Unwrap the list of cotnent types to each denominators
    function unwrapToDenominators(ContentTypes self) internal pure returns (uint8[] memory denominators) {
        // Initial array to 256, the maximum amount of content types
        denominators = new uint8[](256);
        uint256 unwrapped = ContentTypes.unwrap(self);
        uint256 index = 0;

        // Iterate over each possible bit of the array
        for (uint256 i = 0; i < 256; i++) {
            // If the bit is set, we add the type to the array
            if (unwrapped & (1 << i) != 0) {
                denominators[index] = uint8(i);
                index++;
            }
        }

        // Resize our array
        assembly {
            mstore(denominators, index)
        }
    }
}

/* -------------------------------------------------------------------------- */
/*                        The content types denominator                       */
/* -------------------------------------------------------------------------- */

uint8 constant DENOMINATOR_DAPP = 1;
uint8 constant DENOMINATOR_PRESS = 2;

/* -------------------------------------------------------------------------- */
/*                          All of our content types                          */
/* -------------------------------------------------------------------------- */

ContentTypes constant CONTENT_TYPE_DAPP = ContentTypes.wrap(uint256(1 << DENOMINATOR_DAPP));
ContentTypes constant CONTENT_TYPE_PRESS = ContentTypes.wrap(uint256(1 << DENOMINATOR_PRESS));
