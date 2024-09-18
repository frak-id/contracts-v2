// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {InteractionType, InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {
    DENOMINATOR_DAPP, DENOMINATOR_WEB_SHOP, PRODUCT_TYPE_WEB_SHOP, ProductTypes
} from "src/constants/ProductTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {WebShopInteractionFacet} from "src/interaction/facets/WebShopInteractionFacet.sol";

contract WebShopInteractionTest is InteractionTest {
    WebShopInteractionFacet private rawFacet;

    function setUp() public {
        vm.prank(owner);
        productId = productRegistry.mint(PRODUCT_TYPE_WEB_SHOP, "name", "webshop-domain", owner);
        vm.prank(owner);
        productRegistry.setApprovalForAll(operator, true);

        // Deploy the press interaction contract
        _initInteractionTest();

        // Extract the press facet
        rawFacet = WebShopInteractionFacet(address(productInteraction.getFacet(DENOMINATOR_WEB_SHOP)));
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function performSingleInteraction() internal override {
        vm.skip(true);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory a, bytes memory b) {
        vm.skip(true);
        // just for linter stuff
        a = abi.encodePacked("a");
        b = abi.encodePacked("b");
    }

    /* -------------------------------------------------------------------------- */
    /*                             Press related tests                            */
    /* -------------------------------------------------------------------------- */

    function test_construct() public {
        // Can be built
        WebShopInteractionFacet tFacet = new WebShopInteractionFacet();
        assertEq(tFacet.productTypeDenominator(), DENOMINATOR_WEB_SHOP);
    }
}
