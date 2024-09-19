// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";
import "forge-std/Console.sol";
import {InteractionType, PressInteractions} from "src/constants/InteractionType.sol";
import {DENOMINATOR_DAPP, DENOMINATOR_PRESS, PRODUCT_TYPE_PRESS} from "src/constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {PressInteractionFacet} from "src/interaction/facets/PressInteractionFacet.sol";

contract PressInteractionTest is InteractionTest {
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    PressInteractionFacet private rawFacet;

    function setUp() public {
        _initEcosystemAwareTest();

        // Deploy the press interaction contract
        (uint256 _pid, ProductInteractionDiamond _productInteraction) =
            _mintProductWithInteraction(PRODUCT_TYPE_PRESS, "name", "press-domain");
        _initInteractionTest(_pid, _productInteraction);

        // Extract the press facet
        rawFacet = PressInteractionFacet(address(productInteraction.getFacet(DENOMINATOR_PRESS)));
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function performSingleInteraction() internal override {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, _openArticleData(0), alice);
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory, bytes memory) {
        return _prepareInteraction(DENOMINATOR_DAPP, PressInteractions.OPEN_ARTICLE, _openArticleData(0), alice);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Press related tests                            */
    /* -------------------------------------------------------------------------- */

    function test_construct() public {
        // Can be built
        PressInteractionFacet tFacet = new PressInteractionFacet();
        assertEq(tFacet.productTypeDenominator(), DENOMINATOR_PRESS);
    }

    function test_description() public view {
        // TODO: More specific test?
        assertEq(productInteraction.getProductId(), productId);
        assertEq(productInteraction.getFacet(DENOMINATOR_PRESS).productTypeDenominator(), DENOMINATOR_PRESS);

        assertNotEq(productInteraction.getReferralTree(), bytes32(0));
        bytes32 computedReferralTree = keccak256(abi.encodePacked(keccak256("product-referral-tree"), productId));
        assertEq(productInteraction.getReferralTree(), computedReferralTree);
    }

    function test_domainSeparator() public view {
        // TODO: More specific test?
        assertNotEq(productInteraction.getDomainSeparator(), bytes32(0));
    }

    function test_UnknownInteraction() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, InteractionType.wrap(bytes4(0)), _readArticleData(0), alice);

        vm.expectRevert(ProductInteractionDiamond.InteractionHandlingFailed.selector);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test read article                             */
    /* -------------------------------------------------------------------------- */

    function test_articleRead() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(0), alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(productInteraction));
        emit PressInteractionFacet.ArticleRead(0, alice);
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function testFuzz_articleRead(bytes32 _articleId, address _user) public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(_articleId), _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(productInteraction));
        emit PressInteractionFacet.ArticleRead(_articleId, _user);
        // Call the open article method
        vm.prank(_user);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_articleRead_InvalidValidation() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(0), alice);
        (, signature) = _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(0), bob);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ProductInteractionDiamond.WrongInteractionSigner.selector);
        productInteraction.handleInteraction(packedInteraction, signature);

        (, signature) = _prepareInteraction(
            DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(bytes32(uint256(13))), alice
        );

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ProductInteractionDiamond.WrongInteractionSigner.selector);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test open article                             */
    /* -------------------------------------------------------------------------- */

    function test_articleOpened() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, _openArticleData(0), alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(productInteraction));
        emit PressInteractionFacet.ArticleOpened(0, alice);
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function testFuzz_articleOpened(bytes32 _articleId, address _user) public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, _openArticleData(_articleId), _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(productInteraction));
        emit PressInteractionFacet.ArticleOpened(_articleId, _user);
        // Call the open article method
        vm.prank(_user);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Some small helpers                             */
    /* -------------------------------------------------------------------------- */

    function _openArticleData(bytes32 _articleId) private pure returns (bytes memory) {
        return abi.encode(_articleId);
    }

    function _readArticleData(bytes32 _articleId) private pure returns (bytes memory) {
        return abi.encode(_articleId);
    }
}
