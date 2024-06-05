// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ContentInteraction} from "src/interaction/ContentInteraction.sol";
import {PressInteraction} from "src/interaction/PressInteraction.sol";

contract PressInteractionTest is InteractionTest {
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    PressInteraction private pressInteraction;

    function setUp() public {
        // TODO: Setup with a more granular approach
        vm.prank(owner);
        contentId = contentRegistry.mint(CONTENT_TYPE_PRESS, "name", "press-domain");
        vm.prank(owner);
        contentRegistry.setApprovalForAll(operator, true);

        // Deploy the press interaction contract
        pressInteraction = PressInteraction(_initInteractionTest());
        vm.label(address(pressInteraction), "PressInteraction");
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function getNewInstance() internal override returns (address) {
        return address(new PressInteraction(contentId, address(referralRegistry)));
    }

    function performSingleInteraction() internal override {
        bytes32 articleId = 0;
        bytes memory signature = _getInteractionSignature(_readArticleData(articleId), alice);
        // Call the open article method
        vm.prank(alice);
        pressInteraction.articleRead(articleId, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Press related tests                            */
    /* -------------------------------------------------------------------------- */

    function test_description() public view {
        // TODO: More specific test?
        assertEq(pressInteraction.getContentId(), contentId);
        assertEq(ContentTypes.unwrap(pressInteraction.getContentType()), ContentTypes.unwrap(CONTENT_TYPE_PRESS));

        assertNotEq(pressInteraction.getReferralTree(), bytes32(0));
        bytes32 computedReferralTree = keccak256(abi.encodePacked(keccak256("ContentReferralTree"), contentId));
        assertEq(pressInteraction.getReferralTree(), computedReferralTree);
    }

    function test_domainSeparator() public view {
        // TODO: More specific test?
        assertNotEq(pressInteraction.getDomainSeparator(), bytes32(0));
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test read article                             */
    /* -------------------------------------------------------------------------- */

    function test_articleRead() public {
        bytes32 articleId = 0;
        bytes memory signature = _getInteractionSignature(_readArticleData(articleId), alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(pressInteraction));
        emit PressInteraction.ArticleRead(articleId, alice);
        // Call the open article method
        vm.prank(alice);
        pressInteraction.articleRead(articleId, signature);
    }

    function test_articleRead(bytes32 _articleId, address _user) public {
        bytes memory signature = _getInteractionSignature(_readArticleData(_articleId), _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(pressInteraction));
        emit PressInteraction.ArticleRead(_articleId, _user);
        // Call the open article method
        vm.prank(_user);
        pressInteraction.articleRead(_articleId, signature);
    }

    function test_articleRead_InvalidValidation() public {
        bytes32 articleId = 0;
        bytes memory signature = _getInteractionSignature(_readArticleData(articleId), bob);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteraction.WrongInteractionSigner.selector);
        pressInteraction.articleRead(articleId, signature);

        signature = _getInteractionSignature(_readArticleData(bytes32(uint256(13))), alice);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteraction.WrongInteractionSigner.selector);
        pressInteraction.articleRead(articleId, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Test open article                             */
    /* -------------------------------------------------------------------------- */

    function test_articleOpened_simple() public {
        bytes32 articleId = 0;
        bytes memory signature = _getInteractionSignature(_openArticleData(articleId), alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(pressInteraction));
        emit PressInteraction.ArticleOpened(articleId, alice);
        // Call the open article method
        vm.prank(alice);
        pressInteraction.articleOpened(articleId, signature);
    }

    function test_articleOpened_simple(bytes32 _articleId, address _user) public {
        bytes memory signature = _getInteractionSignature(_openArticleData(_articleId), _user);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(pressInteraction));
        emit PressInteraction.ArticleOpened(_articleId, _user);
        // Call the open article method
        vm.prank(_user);
        pressInteraction.articleOpened(_articleId, signature);
    }

    function test_articleOpened_simple_InvalidValidation() public {
        bytes32 articleId = 0;
        bytes memory signature = _getInteractionSignature(_openArticleData(articleId), bob);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteraction.WrongInteractionSigner.selector);
        pressInteraction.articleOpened(articleId, signature);

        signature = _getInteractionSignature(_openArticleData(bytes32(uint256(13))), alice);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteraction.WrongInteractionSigner.selector);
        pressInteraction.articleOpened(articleId, signature);

        signature = _getInteractionSignature(_openArticleData(articleId, bob), alice);

        // Call the open article method
        vm.prank(alice);
        vm.expectRevert(ContentInteraction.WrongInteractionSigner.selector);
        pressInteraction.articleOpened(articleId, signature);
    }

    /// @dev All the case where the share id isn't taken in account
    function test_articleOpened_shared_invalid() public {
        bytes32 articleId = 0;

        bytes memory signature = _getInteractionSignature(_openArticleData(articleId, address(0)), alice);
        vm.prank(alice);
        pressInteraction.articleOpened(articleId, address(0), signature);

        // Ensure no referrer is set
        bytes32 tree = pressInteraction.getReferralTree();
        assertEq(referralRegistry.getReferrer(tree, alice), address(0));
    }

    /// @dev All the case where the share id isn't taken in account
    function test_articleOpened_shared() public {
        bytes32 articleId = 0;

        // Call the open article method
        bytes memory signature = _getInteractionSignature(_openArticleData(articleId, bob), alice);
        // Setup the event check
        vm.expectEmit(true, false, false, true, address(pressInteraction));
        emit PressInteraction.UserReferred(alice, bob);
        vm.prank(alice);
        pressInteraction.articleOpened(articleId, bob, signature);

        // Assert bob is the referrer
        bytes32 tree = pressInteraction.getReferralTree();
        assertEq(referralRegistry.getReferrer(tree, alice), bob);

        // Ensure new shared link won't overwrite initial referrer
        signature = _getInteractionSignature(_openArticleData(articleId, charlie), alice);
        vm.prank(alice);
        pressInteraction.articleOpened(articleId, charlie, signature);
        assertEq(referralRegistry.getReferrer(tree, alice), bob);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Some small helpers                             */
    /* -------------------------------------------------------------------------- */

    function _openArticleData(bytes32 _articleId) private pure returns (bytes32) {
        return _openArticleData(_articleId, address(0));
    }

    function _openArticleData(bytes32 _articleId, address _referrer) private pure returns (bytes32) {
        return keccak256(
            abi.encode(0xc0a24ffb7afa254ad3052f8f1da6e4268b30580018115d9c10b63352b0004b2d, _articleId, _referrer)
        );
    }

    function _readArticleData(bytes32 _articleId) private pure returns (bytes32) {
        return keccak256(abi.encode(0xd5bd0fbe3510f2dde55a90e8bb325735d540cc475e1875f00abfd5a81015b073, _articleId));
    }

    function test_reinit() public {
        vm.expectRevert();
        pressInteraction.init(address(1), address(1), address(1));

        // Ensure we can't init raw instance
        PressInteraction rawImplem = new PressInteraction(contentId, address(referralRegistry));
        vm.expectRevert();
        rawImplem.init(address(1), address(1), address(1));
    }
}
