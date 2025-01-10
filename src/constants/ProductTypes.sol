// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev Global type for a bytes32 olding multiple product types
type ProductTypes is uint256;

using {productTypesOr as |} for ProductTypes global;

/// @dev Simple wrapper to pack / unpack product types
function productTypesOr(ProductTypes self, ProductTypes other) pure returns (ProductTypes result) {
    return ProductTypes.wrap(ProductTypes.unwrap(self) | ProductTypes.unwrap(other));
}

using ProductTypesLib for ProductTypes global;

/// @dev Set of helper functions for product types
library ProductTypesLib {
    function isEmpty(ProductTypes self) internal pure returns (bool isType) {
        return ProductTypes.unwrap(self) == 0;
    }

    function isDappType(ProductTypes self) internal pure returns (bool isType) {
        return self.containType(PRODUCT_TYPE_DAPP);
    }

    function isPressType(ProductTypes self) internal pure returns (bool isType) {
        return self.containType(PRODUCT_TYPE_PRESS);
    }

    function isWebShopType(ProductTypes self) internal pure returns (bool isType) {
        return self.containType(PRODUCT_TYPE_WEB_SHOP);
    }

    function isRetailType(ProductTypes self) internal pure returns (bool isType) {
        return self.containType(PRODUCT_TYPE_RETAIL);
    }

    function hasReferralFeature(ProductTypes self) internal pure returns (bool isType) {
        return self.containType(PRODUCT_TYPE_FEATURE_REFERRAL);
    }

    function hasPurchaseFeature(ProductTypes self) internal pure returns (bool isType) {
        return self.containType(PRODUCT_TYPE_FEATURE_PURCHASE);
    }

    function containType(ProductTypes self, ProductTypes typeToCheck) internal pure returns (bool containsType) {
        return ProductTypes.unwrap(self) & ProductTypes.unwrap(typeToCheck) != 0;
    }

    /// @dev Unwrap the list of cotnent types to each denominators
    function unwrapToDenominators(ProductTypes self) internal pure returns (uint8[] memory denominators) {
        unchecked {
            // Initial array to 256, the maximum amount of product types
            denominators = new uint8[](256);
            uint256 unwrapped = ProductTypes.unwrap(self);
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
}

/* -------------------------------------------------------------------------- */
/*                        The product types denominator                       */
/* -------------------------------------------------------------------------- */

// Global product types
uint8 constant DENOMINATOR_DAPP = 1;
uint8 constant DENOMINATOR_PRESS = 2;
uint8 constant DENOMINATOR_WEB_SHOP = 3;
uint8 constant DENOMINATOR_RETAIL = 4;

// Feature types denominators
uint8 constant DENOMINATOR_FEATURE_REFERRAL = 30;
uint8 constant DENOMINATOR_FEATURE_PURCHASE = 31;

/* -------------------------------------------------------------------------- */
/*                          All of our product types                          */
/* -------------------------------------------------------------------------- */

ProductTypes constant PRODUCT_TYPE_DAPP = ProductTypes.wrap(uint256(1 << DENOMINATOR_DAPP));
ProductTypes constant PRODUCT_TYPE_PRESS = ProductTypes.wrap(uint256(1 << DENOMINATOR_PRESS));
ProductTypes constant PRODUCT_TYPE_WEB_SHOP = ProductTypes.wrap(uint256(1 << DENOMINATOR_WEB_SHOP));
ProductTypes constant PRODUCT_TYPE_RETAIL = ProductTypes.wrap(uint256(1 << DENOMINATOR_RETAIL));

ProductTypes constant PRODUCT_TYPE_FEATURE_REFERRAL = ProductTypes.wrap(uint256(1 << DENOMINATOR_FEATURE_REFERRAL));
ProductTypes constant PRODUCT_TYPE_FEATURE_PURCHASE = ProductTypes.wrap(uint256(1 << DENOMINATOR_FEATURE_PURCHASE));
