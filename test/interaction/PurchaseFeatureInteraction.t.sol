// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {InteractionType, InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {
    DENOMINATOR_DAPP,
    DENOMINATOR_FEATURE_PURCHASE,
    PRODUCT_TYPE_FEATURE_PURCHASE,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {PurchaseFeatureFacet} from "src/interaction/facets/PurchaseFeatureFacet.sol";

contract PurchaseFeatureInteractionTest is InteractionTest {
    PurchaseFeatureFacet private rawFacet;

    function setUp() public {
        vm.prank(owner);
        productId = productRegistry.mint(PRODUCT_TYPE_FEATURE_PURCHASE, "name", "purchase-domain", owner);
        vm.prank(owner);
        productRegistry.setApprovalForAll(operator, true);

        // Deploy the press interaction contract
        _initInteractionTest();

        // Extract the press facet
        rawFacet = PurchaseFeatureFacet(address(productInteraction.getFacet(DENOMINATOR_FEATURE_PURCHASE)));
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
        PurchaseFeatureFacet tFacet = new PurchaseFeatureFacet(purchaseOracle);
        assertEq(tFacet.productTypeDenominator(), DENOMINATOR_FEATURE_PURCHASE);
    }
}
