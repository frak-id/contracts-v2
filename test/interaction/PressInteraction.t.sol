// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CONTENT_TYPE_PRESS, ContentTypes, DENOMINATOR_PRESS} from "src/constants/ContentTypes.sol";

import {InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {PressInteractionFacet} from "src/interaction/facets/PressInteractionFacet.sol";

contract PressInteractionTest is InteractionTest {
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    function setUp() public {
        // TODO: Setup with a more granular approach
        vm.prank(owner);
        contentId = contentRegistry.mint(CONTENT_TYPE_PRESS, "name", "press-domain");
        vm.prank(owner);
        contentRegistry.setApprovalForAll(operator, true);

        // Deploy the press interaction contract
        _initInteractionTest();
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function performSingleInteraction() internal override {
        bytes memory interactionData = _openArticleData(0);
        bytes memory signature = _getInteractionSignature(PressInteractions.OPEN_ARTICLE, interactionData, alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(
            DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, interactionData, signature
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                             Press related tests                            */
    /* -------------------------------------------------------------------------- */

    function test_description() public view {
        // TODO: More specific test?
        assertEq(contentInteraction.getContentId(), contentId);
        assertEq(contentInteraction.getFacet(DENOMINATOR_PRESS).contentTypeDenominator(), DENOMINATOR_PRESS);

        assertNotEq(contentInteraction.getReferralTree(), bytes32(0));
        bytes32 computedReferralTree = keccak256(abi.encodePacked(keccak256("ContentReferralTree"), contentId));
        assertEq(contentInteraction.getReferralTree(), computedReferralTree);
    }

    function test_domainSeparator() public view {
        // TODO: More specific test?
        assertNotEq(contentInteraction.getDomainSeparator(), bytes32(0));
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test read article                             */
    /* -------------------------------------------------------------------------- */

    function test_articleRead() public {
        bytes memory interactionData = _readArticleData(0);
        bytes memory signature = _getInteractionSignature(PressInteractions.READ_ARTICLE, interactionData, alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.ArticleRead(0, alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(
            DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, interactionData, signature
        );
    }

    function test_articleRead(bytes32 _articleId, address _user) public {
        bytes memory interactionData = _readArticleData(_articleId);
        bytes memory signature = _getInteractionSignature(PressInteractions.READ_ARTICLE, interactionData, _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.ArticleRead(_articleId, _user);
        // Call the open article method
        vm.prank(_user);
        contentInteraction.handleInteraction(
            DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, interactionData, signature
        );
    }

    function test_articleRead_InvalidValidation() public {
        bytes memory interactionData = _readArticleData(0);
        bytes memory signature = _getInteractionSignature(PressInteractions.READ_ARTICLE, interactionData, bob);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteractionDiamond.WrongInteractionSigner.selector);
        contentInteraction.handleInteraction(
            DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, interactionData, signature
        );

        signature =
            _getInteractionSignature(PressInteractions.READ_ARTICLE, _readArticleData(bytes32(uint256(13))), alice);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteractionDiamond.WrongInteractionSigner.selector);
        contentInteraction.handleInteraction(
            DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, interactionData, signature
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test open article                             */
    /* -------------------------------------------------------------------------- */

    function test_articleOpened_simple() public {
        bytes memory interactionData = _openArticleData(0);
        bytes memory signature = _getInteractionSignature(PressInteractions.OPEN_ARTICLE, interactionData, alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.ArticleOpened(0, alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(
            DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, interactionData, signature
        );
    }

    function test_articleOpened_simple(bytes32 _articleId, address _user) public {
        bytes memory interactionData = _openArticleData(_articleId);
        bytes memory signature = _getInteractionSignature(PressInteractions.OPEN_ARTICLE, interactionData, _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.ArticleOpened(_articleId, _user);
        // Call the open article method
        vm.prank(_user);
        contentInteraction.handleInteraction(
            DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, interactionData, signature
        );
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

    function _referredData(address _referrer) private pure returns (bytes memory) {
        return abi.encode(_referrer);
    }
}
