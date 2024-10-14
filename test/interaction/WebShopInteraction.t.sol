// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {
    InteractionType,
    InteractionTypeLib,
    PressInteractions,
    WebShopInteractions
} from "src/constants/InteractionType.sol";
import {
    DENOMINATOR_DAPP, DENOMINATOR_WEB_SHOP, PRODUCT_TYPE_WEB_SHOP, ProductTypes
} from "src/constants/ProductTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {WebShopInteractionFacet} from "src/interaction/facets/WebShopInteractionFacet.sol";

contract WebShopInteractionTest is InteractionTest {
    address private alice = makeAddr("alice");
    WebShopInteractionFacet private rawFacet;

    function setUp() public {
        _initEcosystemAwareTest();

        (uint256 _pid, ProductInteractionDiamond _productInteraction) =
            _mintProductWithInteraction(PRODUCT_TYPE_WEB_SHOP, "name", "webshop-domain");
        _initInteractionTest(_pid, _productInteraction);

        // Extract the press facet
        rawFacet = WebShopInteractionFacet(address(productInteraction.getFacet(DENOMINATOR_WEB_SHOP)));
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function performSingleInteraction() internal override {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_WEB_SHOP, WebShopInteractions.OPEN, "", alice);
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory a, bytes memory b) {
        return _prepareInteraction(DENOMINATOR_DAPP, WebShopInteractions.OPEN, "", alice);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Press related tests                            */
    /* -------------------------------------------------------------------------- */

    function test_construct() public {
        // Can be built
        WebShopInteractionFacet tFacet = new WebShopInteractionFacet();
        assertEq(tFacet.productTypeDenominator(), DENOMINATOR_WEB_SHOP);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test webshop open                             */
    /* -------------------------------------------------------------------------- */

    function test_webshopOpen() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_WEB_SHOP, WebShopInteractions.OPEN, "", alice);

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit WebShopInteractionFacet.WebShopOpenned(alice);
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function testFuzz_webshopOpen(address _user) public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_WEB_SHOP, WebShopInteractions.OPEN, "", _user);

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit WebShopInteractionFacet.WebShopOpenned(_user);
        // Call the open article method
        vm.prank(_user);
        productInteraction.handleInteraction(packedInteraction, signature);
    }
}
