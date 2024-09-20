// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import {PRODUCT_TYPE_PRESS} from "src/constants/ProductTypes.sol";

contract PurchaseOracleTest is EcosystemAwareTest {
    uint256 productId;

    function setUp() public {
        _initEcosystemAwareTest();

        // Setup a random product
        productId = _mintProduct(PRODUCT_TYPE_PRESS, "name", "random-domain");
    }
}
