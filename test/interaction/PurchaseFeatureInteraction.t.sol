// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Merkle} from "lib/murky/src/Merkle.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {InteractionType, InteractionTypeLib, PurchaseInteractions} from "src/constants/InteractionType.sol";
import {
    DENOMINATOR_DAPP,
    DENOMINATOR_FEATURE_PURCHASE,
    PRODUCT_TYPE_FEATURE_PURCHASE,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {INTERCATION_VALIDATOR_ROLE, PURCHASE_ORACLE_OPERATOR_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {PurchaseFeatureFacet} from "src/interaction/facets/PurchaseFeatureFacet.sol";
import {PurchaseStatus} from "src/oracle/IPurchaseOracle.sol";

contract PurchaseFeatureInteractionTest is InteractionTest {
    address private alice = makeAddr("alice");

    address internal oracleOperator = makeAddr("oracleOperator");

    PurchaseFeatureFacet private rawFacet;

    /// Murky merkle helper
    Merkle m = new Merkle();

    function setUp() public {
        _initEcosystemAwareTest();

        // Deploy the press interaction contract
        (uint256 _pid, ProductInteractionDiamond _productInteraction) =
            _mintProductWithInteraction(PRODUCT_TYPE_FEATURE_PURCHASE, "name", "purchase-domain");
        _initInteractionTest(_pid, _productInteraction);

        // Extract the press facet
        rawFacet = PurchaseFeatureFacet(address(productInteraction.getFacet(DENOMINATOR_FEATURE_PURCHASE)));

        // Grant the right roles to the purchase oracle
        vm.prank(productOwner);
        adminRegistry.grantRoles(_pid, oracleOperator, PURCHASE_ORACLE_OPERATOR_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */

    function performSingleInteraction() internal override {
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE, PurchaseInteractions.PURCHASE_STARTED, _purchaseStartedData(0), alice
        );
        // Call the open article method
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory, bytes memory) {
        return
            _prepareInteraction(DENOMINATOR_DAPP, PurchaseInteractions.PURCHASE_STARTED, _purchaseStartedData(0), alice);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Facet related test                             */
    /* -------------------------------------------------------------------------- */

    function test_construct() public {
        // Can be built
        PurchaseFeatureFacet tFacet = new PurchaseFeatureFacet(purchaseOracle);
        assertEq(tFacet.productTypeDenominator(), DENOMINATOR_FEATURE_PURCHASE);
    }

    function test_description() public view {
        assertEq(productInteraction.getProductId(), productId);
        assertEq(
            productInteraction.getFacet(DENOMINATOR_FEATURE_PURCHASE).productTypeDenominator(),
            DENOMINATOR_FEATURE_PURCHASE
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                            Test purchase started                           */
    /* -------------------------------------------------------------------------- */

    function test_purchaseStarted() public {
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE, PurchaseInteractions.PURCHASE_STARTED, _purchaseStartedData(0), alice
        );

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit PurchaseFeatureFacet.PurchaseStarted(0, alice);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function testFuzz_purchaseStarted(uint256 _purchaseId) public {
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE,
            PurchaseInteractions.PURCHASE_STARTED,
            _purchaseStartedData(_purchaseId),
            alice
        );

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit PurchaseFeatureFacet.PurchaseStarted(_purchaseId, alice);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Test purchase completed                          */
    /* -------------------------------------------------------------------------- */

    function test_purchaseCompleted() public {
        bytes32[] memory proof = _setOracleAndGetProof(0, PurchaseStatus.Completed);
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE,
            PurchaseInteractions.PURCHASE_COMPLETED,
            _purchaseCompletedData(0, proof),
            alice
        );

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit PurchaseFeatureFacet.PurchaseCompleted(0, alice);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function testFuzz_purchaseCompleted(uint256 _purchaseId) public {
        bytes32[] memory proof = _setOracleAndGetProof(_purchaseId, PurchaseStatus.Completed);
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE,
            PurchaseInteractions.PURCHASE_COMPLETED,
            _purchaseCompletedData(_purchaseId, proof),
            alice
        );

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit PurchaseFeatureFacet.PurchaseCompleted(_purchaseId, alice);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_purchaseCompleted_DontHandleTwice() public {
        bytes32[] memory proof = _setOracleAndGetProof(0, PurchaseStatus.Completed);
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE,
            PurchaseInteractions.PURCHASE_COMPLETED,
            _purchaseCompletedData(0, proof),
            alice
        );

        // Setup the event check
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit PurchaseFeatureFacet.PurchaseCompleted(0, alice);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);

        // Resend an interaction about the same purchase
        (packedInteraction, signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE,
            PurchaseInteractions.PURCHASE_COMPLETED,
            _purchaseCompletedData(0, proof),
            alice
        );
        vm.expectRevert(ProductInteractionDiamond.InteractionHandlingFailed.selector);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_purchaseCompleted_NotCompleted() public {
        bytes32[] memory proof = _setOracleAndGetProof(0, PurchaseStatus.Cancelled);
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE,
            PurchaseInteractions.PURCHASE_COMPLETED,
            _purchaseCompletedData(0, proof),
            alice
        );

        // Expect a revert error
        vm.expectRevert(ProductInteractionDiamond.InteractionHandlingFailed.selector);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_purchaseCompleted_OracleNotSet() public {
        bytes32[] memory proof = _setOracleAndGetProof(0, PurchaseStatus.Cancelled);
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_FEATURE_PURCHASE,
            PurchaseInteractions.PURCHASE_COMPLETED,
            _purchaseCompletedData(0, proof),
            alice
        );

        // Reset the oracle
        vm.prank(oracleOperator);
        purchaseOracle.updateMerkleRoot(productId, bytes32(0));

        // Expect a revert error
        vm.expectRevert(ProductInteractionDiamond.InteractionHandlingFailed.selector);
        vm.prank(alice);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function _purchaseStartedData(uint256 _purchaseId) private pure returns (bytes memory) {
        return abi.encode(_purchaseId);
    }

    function _purchaseCompletedData(uint256 _purchaseId, bytes32[] memory _proof) private pure returns (bytes memory) {
        return abi.encode(_purchaseId, _proof);
    }

    function _setOracleAndGetProof(uint256 _purchaseId, PurchaseStatus _status)
        private
        returns (bytes32[] memory proof)
    {
        vm.pauseGasMetering();

        // data that will be used for the merklee tree
        bytes32[] memory data = new bytes32[](10);

        // Create 9 random leafs
        for (uint256 i = 0; i < 9; i++) {
            data[i] = keccak256(abi.encodePacked(i));
        }

        // Finally insert the leaf we want
        bytes32 leaf = keccak256(abi.encodePacked(_purchaseId, _status));
        data[9] = leaf;

        // Generate the tree
        bytes32 root = m.getRoot(data);
        proof = m.getProof(data, 9);

        // Update the oracle tree
        vm.prank(oracleOperator);
        purchaseOracle.updateMerkleRoot(productId, root);

        vm.resetGasMetering();
    }
}
