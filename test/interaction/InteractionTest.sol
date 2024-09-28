// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import "forge-std/Console.sol";
import {InteractionType, InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";

/// @dev Generic contract to test interaction
abstract contract InteractionTest is EcosystemAwareTest {
    uint256 internal productId;

    uint256 internal validatorPrivKey;
    address internal validator;

    ProductInteractionDiamond internal productInteraction;

    bytes32 internal referralTree;

    /// @dev Initialize the test
    function _initInteractionTest(uint256 _productId, ProductInteractionDiamond _productInteraction) internal {
        // Create our validator ECDSA
        (validator, validatorPrivKey) = makeAddrAndKey("validator");

        productId = _productId;
        productInteraction = _productInteraction;
        referralTree = _productInteraction.getReferralTree();

        // Grant the validator roles
        vm.prank(productOwner);
        _productInteraction.grantRoles(validator, INTERCATION_VALIDATOR_ROLE);
    }

    // Validation type hash
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH =
        keccak256("ValidateInteraction(uint256 productId,bytes32 interactionData,address user)");

    /// @dev Prepare some interaction data
    function _prepareInteraction(
        uint8 productTypeDenominator,
        InteractionType action,
        bytes memory interactionData,
        address user
    ) internal returns (bytes memory data, bytes memory signature) {
        vm.pauseGasMetering();
        bytes memory facetData = abi.encodePacked(action, interactionData);
        data = abi.encodePacked(productTypeDenominator, facetData);
        signature = _getInteractionSignature(facetData, user);
        vm.resumeGasMetering();
    }

    /// @dev Generate an interaction signature for the given interaction data
    function _getInteractionSignature(bytes memory _interactionData, address _user)
        private
        view
        returns (bytes memory signature)
    {
        bytes32 domainSeparator = productInteraction.getDomainSeparator();

        // Build the digest
        bytes32 dataHash =
            keccak256(abi.encode(_VALIDATE_INTERACTION_TYPEHASH, productId, keccak256(_interactionData), _user));
        bytes32 fullHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, dataHash));

        // Sign the full hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivKey, fullHash);
        if (v != 27) {
            // then left-most bit of s has to be flipped to 1.
            s = s | bytes32(uint256(1) << 255);
        }

        // Compact the signature into a single byte
        signature = abi.encodePacked(r, s);
    }

    /* -------------------------------------------------------------------------- */
    /*                  Asbtract function to generate a few tests                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Perform some event with interaction
    function performSingleInteraction() internal virtual;

    /// @dev Perform an interaction out of the facet scope
    function getOutOfFacetScopeInteraction() internal virtual returns (bytes memory, bytes memory);

    /* -------------------------------------------------------------------------- */
    /*                             Some generic tests                             */
    /* -------------------------------------------------------------------------- */

    function test_UnandledProductType() public {
        (bytes memory packedInteraction, bytes memory signature) = getOutOfFacetScopeInteraction();

        // Call the operation
        vm.expectRevert(ProductInteractionDiamond.UnandledProductType.selector);
        productInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_singleCampaign() public {
        performSingleInteraction();
    }
}
