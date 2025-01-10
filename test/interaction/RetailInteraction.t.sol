// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";
import "forge-std/Console.sol";
import {InteractionType, RetailInteractions} from "src/constants/InteractionType.sol";
import {DENOMINATOR_DAPP, DENOMINATOR_RETAIL, PRODUCT_TYPE_RETAIL} from "src/constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {RetailInteractionFacet} from "src/interaction/facets/RetailInteractionFacet.sol";

contract RetailInteractionTest is InteractionTest {
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    RetailInteractionFacet private rawFacet;

    function setUp() public {
        _initEcosystemAwareTest();

        // Deploy the press interaction contract
        (uint256 _pid, ProductInteractionDiamond _productInteraction) =
            _mintProductWithInteraction(PRODUCT_TYPE_RETAIL, "name", "retail-domain");
        _initInteractionTest(_pid, _productInteraction);

        // Extract the press facet
        rawFacet = RetailInteractionFacet(address(productInteraction.getFacet(DENOMINATOR_RETAIL)));
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function performSingleInteraction() internal override {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_RETAIL, RetailInteractions.CUSTOMER_MEETING, _customerMeetingData(0), alice);
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory, bytes memory) {
        return
            _prepareInteraction(DENOMINATOR_DAPP, RetailInteractions.CUSTOMER_MEETING, _customerMeetingData(0), alice);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Press related tests                            */
    /* -------------------------------------------------------------------------- */

    function test_construct() public {
        // Can be built
        RetailInteractionFacet tFacet = new RetailInteractionFacet();
        assertEq(tFacet.productTypeDenominator(), DENOMINATOR_RETAIL);
    }

    function test_description() public view {
        // TODO: More specific test?
        assertEq(productInteraction.getProductId(), productId);
        assertEq(productInteraction.getFacet(DENOMINATOR_RETAIL).productTypeDenominator(), DENOMINATOR_RETAIL);

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
            _prepareInteraction(DENOMINATOR_RETAIL, InteractionType.wrap(bytes4(0)), _customerMeetingData(0), alice);

        vm.expectRevert(ProductInteractionDiamond.InteractionHandlingFailed.selector);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Test customer meeting                           */
    /* -------------------------------------------------------------------------- */

    function test_customerMeeting() public {
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(DENOMINATOR_RETAIL, RetailInteractions.CUSTOMER_MEETING, _customerMeetingData(0), alice);

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit RetailInteractionFacet.CustomerMeeting(0, alice);
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function testFuzz_customerMeeting(bytes32 _agencyId, address _user) public {
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_RETAIL, RetailInteractions.CUSTOMER_MEETING, _customerMeetingData(_agencyId), _user
        );

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit RetailInteractionFacet.CustomerMeeting(_agencyId, _user);
        // Call the open article method
        vm.prank(_user);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Some small helpers                             */
    /* -------------------------------------------------------------------------- */

    function _customerMeetingData(bytes32 _agencyId) private pure returns (bytes memory) {
        return abi.encode(_agencyId);
    }
}
