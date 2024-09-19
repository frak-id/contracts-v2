// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {InteractionType, InteractionTypeLib, ReferralInteractions} from "src/constants/InteractionType.sol";
import {
    DENOMINATOR_DAPP,
    DENOMINATOR_FEATURE_REFERRAL,
    DENOMINATOR_PRESS,
    PRODUCT_TYPE_FEATURE_REFERRAL,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ReferralFeatureFacet} from "src/interaction/facets/ReferralFeatureFacet.sol";

contract ReferralInteractionTest is InteractionTest {
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    ReferralFeatureFacet private rawFacet;

    function setUp() public {
        _initEcosystemAwareTest();

        // Deploy the press interaction contract
        (uint256 _pid, ProductInteractionDiamond _productInteraction) =
            _mintProductWithInteraction(PRODUCT_TYPE_FEATURE_REFERRAL, "name", "referral-domain");
        _initInteractionTest(_pid, _productInteraction);

        // Extract the press facet
        rawFacet = ReferralFeatureFacet(address(productInteraction.getFacet(DENOMINATOR_FEATURE_REFERRAL)));
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function performSingleInteraction() internal override {
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_REFERRAL, ReferralInteractions.REFERRAL_LINK_CREATION, _linkCreationData(), alice
        );
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory, bytes memory) {
        return _prepareInteraction(
            DENOMINATOR_DAPP, ReferralInteractions.REFERRAL_LINK_CREATION, _linkCreationData(), alice
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                         Test referral link creation                        */
    /* -------------------------------------------------------------------------- */

    function test_referralLinkCreation() public {
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_REFERRAL, ReferralInteractions.REFERRAL_LINK_CREATION, _linkCreationData(), alice
        );

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(productInteraction));
        emit ReferralFeatureFacet.ReferralLinkCreation(alice);
        // Call the open referral method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Test referred                               */
    /* -------------------------------------------------------------------------- */

    function test_referred() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_FEATURE_REFERRAL, ReferralInteractions.REFERRED, _referredData(bob), alice);

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(productInteraction));
        emit ReferralFeatureFacet.UserReferred(alice, bob);
        // Call the open referral method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);

        assertEq(referralRegistry.getReferrer(referralTree, alice), bob);
    }

    function testFuzz_referred(address _user, address _referrer) public {
        vm.assume(_user != address(0) && _referrer != address(0) && _user != _referrer);
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_REFERRAL, ReferralInteractions.REFERRED, _referredData(_referrer), _user
        );

        // Setup the event check
        vm.expectEmit(true, false, false, true, address(productInteraction));
        emit ReferralFeatureFacet.UserReferred(_user, _referrer);
        // Call the open referral method
        vm.prank(_user);
        productInteraction.handleInteraction(packedInteraction, signature);

        assertEq(referralRegistry.getReferrer(referralTree, _user), _referrer);
    }

    function test_referred_doNothing() public {
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_REFERRAL, ReferralInteractions.REFERRED, _referredData(address(0)), alice
        );

        // Call the referral method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);

        assertEq(referralRegistry.getReferrer(referralTree, alice), address(0));
    }

    function test_referred_alreadyHasReferrer() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_FEATURE_REFERRAL, ReferralInteractions.REFERRED, _referredData(bob), alice);

        // Call the referral method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
        assertEq(referralRegistry.getReferrer(referralTree, alice), bob);

        (packedInteraction, signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_REFERRAL, ReferralInteractions.REFERRED, _referredData(charlie), alice
        );
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);

        // Ensure it hasn't changed
        assertEq(referralRegistry.getReferrer(referralTree, alice), bob);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Some small helpers                             */
    /* -------------------------------------------------------------------------- */

    function _linkCreationData() private pure returns (bytes memory) {
        return "";
    }

    function _referredData(address _referrer) private pure returns (bytes memory) {
        return abi.encode(_referrer);
    }
}
