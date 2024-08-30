// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CampaignFactory} from "src/campaign/CampaignFactory.sol";

import {InteractionType, InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {PRODUCT_TYPE_PRESS} from "src/constants/ProductTypes.sol";
import {INTERCATION_VALIDATOR_ROLE, REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";

import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";

import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

/// @dev Generic contract to test interaction
abstract contract InteractionTest is Test {
    uint256 internal productId;

    address internal owner = makeAddr("owner");
    address internal operator = makeAddr("operator");

    ProductRegistry internal productRegistry = new ProductRegistry(owner);
    ReferralRegistry internal referralRegistry = new ReferralRegistry(owner);
    ProductAdministratorRegistry internal adminRegistry = new ProductAdministratorRegistry(productRegistry);
    ProductInteractionManager internal productInteractionManager;
    InteractionFacetsFactory internal facetFactory;
    CampaignFactory internal campaignFactory;

    uint256 internal validatorPrivKey;
    address internal validator;

    ProductInteractionDiamond internal productInteraction;

    bytes32 internal referralTree;

    function _initInteractionTest() internal {
        // Create our validator ECDSA
        (validator, validatorPrivKey) = makeAddrAndKey("validator");

        facetFactory = new InteractionFacetsFactory(referralRegistry, productRegistry, adminRegistry);
        campaignFactory = new CampaignFactory(referralRegistry, adminRegistry, owner);

        // Create our content interaction
        address implem = address(new ProductInteractionManager(productRegistry, referralRegistry, adminRegistry));
        address proxy = LibClone.deployERC1967(implem);
        productInteractionManager = ProductInteractionManager(proxy);
        productInteractionManager.init(owner, facetFactory, campaignFactory);

        // Grant the right roles to the content interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(address(productInteractionManager), REFERRAL_ALLOWANCE_MANAGER_ROLE);

        // Deploy the interaction contract
        vm.prank(operator);
        productInteractionManager.deployInteractionContract(productId);
        productInteraction = productInteractionManager.getInteractionContract(productId);
        vm.label(address(productInteraction), "ProductInteractionDiamond");

        referralTree = productInteraction.getReferralTree();

        // Grant the validator roles
        vm.prank(owner);
        productInteraction.grantRoles(validator, INTERCATION_VALIDATOR_ROLE);
    }

    // Validation type hash
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH =
        keccak256("ValidateInteraction(uint256 productId,bytes32 interactionData,address user,uint256 nonce)");

    /// @dev Generate an interaction signature for the given interaction data
    function _getInteractionSignature(bytes memory _interactionData, address _user)
        internal
        view
        returns (bytes memory signature)
    {
        uint256 nonce = productInteraction.getNonceForInteraction(keccak256(_interactionData), _user);
        bytes32 domainSeparator = productInteraction.getDomainSeparator();

        // Build the digest
        bytes32 dataHash =
            keccak256(abi.encode(_VALIDATE_INTERACTION_TYPEHASH, productId, keccak256(_interactionData), _user, nonce));
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
