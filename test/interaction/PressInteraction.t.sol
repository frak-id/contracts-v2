// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CONTENT_TYPE_PRESS, ContentTypes, DENOMINATOR_DAPP, DENOMINATOR_PRESS} from "src/constants/ContentTypes.sol";
import {InteractionType, InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {PressInteractionFacet} from "src/interaction/facets/PressInteractionFacet.sol";

contract PressInteractionTest is InteractionTest {
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    PressInteractionFacet private rawFacet;

    function setUp() public {
        // TODO: Setup with a more granular approach
        vm.prank(owner);
        contentId = contentRegistry.mint(CONTENT_TYPE_PRESS, "name", "press-domain");
        vm.prank(owner);
        contentRegistry.setApprovalForAll(operator, true);

        // Deploy the press interaction contract
        _initInteractionTest();

        // Extract the press facet
        rawFacet = PressInteractionFacet(address(contentInteraction.getFacet(DENOMINATOR_PRESS)));
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function performSingleInteraction() internal override {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, _openArticleData(0), alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory, bytes memory) {
        return _prepareInteraction(DENOMINATOR_DAPP, PressInteractions.OPEN_ARTICLE, _openArticleData(0), alice);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Press related tests                            */
    /* -------------------------------------------------------------------------- */

    function test_construct() public {
        // Can be built
        PressInteractionFacet tFacet = new PressInteractionFacet(referralRegistry);
        assertEq(tFacet.contentTypeDenominator(), DENOMINATOR_PRESS);
    }

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

    function test_UnknownInteraction() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, InteractionType.wrap(bytes4(0)), _readArticleData(0), alice);

        vm.expectRevert(ContentInteractionDiamond.InteractionHandlingFailed.selector);
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test read article                             */
    /* -------------------------------------------------------------------------- */

    function test_articleRead() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(0), alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.ArticleRead(0, alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_articleRead(bytes32 _articleId, address _user) public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(_articleId), _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.ArticleRead(_articleId, _user);
        // Call the open article method
        vm.prank(_user);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_articleRead_InvalidValidation() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(0), alice);
        (, signature) = _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(0), bob);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteractionDiamond.WrongInteractionSigner.selector);
        contentInteraction.handleInteraction(packedInteraction, signature);

        (, signature) = _prepareInteraction(
            DENOMINATOR_PRESS, PressInteractions.READ_ARTICLE, _readArticleData(bytes32(uint256(13))), alice
        );

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteractionDiamond.WrongInteractionSigner.selector);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test open article                             */
    /* -------------------------------------------------------------------------- */

    function test_articleOpened_simple() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, _openArticleData(0), alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.ArticleOpened(0, alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_articleOpened_simple(bytes32 _articleId, address _user) public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, _openArticleData(_articleId), _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.ArticleOpened(_articleId, _user);
        // Call the open article method
        vm.prank(_user);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Test referred                               */
    /* -------------------------------------------------------------------------- */

    function test_referred_simple() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.REFERRED, _referredData(bob), alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.UserReferred(alice, bob);
        // Call the open referral method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);

        assertEq(referralRegistry.getReferrer(referralTree, alice), bob);
    }

    function test_referred_simple(address _user, address _referrer) public {
        vm.assume(_user != address(0) && _referrer != address(0));
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.REFERRED, _referredData(_referrer), _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(contentInteraction));
        emit PressInteractionFacet.UserReferred(_user, _referrer);
        // Call the open referral method
        vm.prank(_user);
        contentInteraction.handleInteraction(packedInteraction, signature);

        assertEq(referralRegistry.getReferrer(referralTree, _user), _referrer);
    }

    function test_referred_doNothing() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.REFERRED, _referredData(address(0)), alice);

        // Call the referral method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);

        assertEq(referralRegistry.getReferrer(referralTree, alice), address(0));
    }

    function test_referred_alreadyHasReferrer() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.REFERRED, _referredData(bob), alice);

        // Call the referral method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);
        assertEq(referralRegistry.getReferrer(referralTree, alice), bob);

        (packedInteraction, signature) =
            _prepareInteraction(DENOMINATOR_PRESS, PressInteractions.REFERRED, _referredData(charlie), alice);
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);

        // Ensure it hasn't changed
        assertEq(referralRegistry.getReferrer(referralTree, alice), bob);
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
