// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import "forge-std/Console.sol";

import {CampaignBank} from "src/campaign/CampaignBank.sol";
import {
    ReferralCampaign, ReferralCampaignConfig, ReferralCampaignTriggerConfig
} from "src/campaign/ReferralCampaign.sol";
import {
    InteractionType,
    InteractionTypeLib,
    PressInteractions,
    ReferralInteractions
} from "src/constants/InteractionType.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";

/// @dev Generic contract to test interaction
abstract contract InteractionTest is EcosystemAwareTest {
    uint256 internal productId;

    uint256 internal validatorPrivKey;
    address internal validator;

    ProductInteractionDiamond internal productInteraction;

    bytes32 internal referralTree;

    /// @dev The bank we will use
    CampaignBank private campaignBank;

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

        // Deploy a single bank
        // We don't rly need to productId here since every product has the same roles
        campaignBank = new CampaignBank(adminRegistry, productId, address(token));

        // Mint a few test tokens to the campaign
        token.mint(address(campaignBank), 1000 ether);
        // Start our bank
        vm.prank(productOwner);
        campaignBank.updateDistributionState(true);
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
        bytes memory handleInteractionSelector =
            abi.encodeWithSelector(0xc375ab13);
        // Deploy a campaign
        bytes4 campaignId = bytes4(keccak256("frak.campaign.referral"));
        bytes memory initData = _getReferralCampaignConfigInitData();

        // Deploy the campaign
        vm.prank(productOwner);
        address campaign = productInteractionManager.deployCampaign(productId, campaignId, initData);

        // Perform the interaction and ensure the campaign is called
        vm.expectCall(campaign, handleInteractionSelector);
        performSingleInteraction();
    }

    function test_multiCampaign() public {
        bytes memory handleInteractionSelector =
            abi.encodeWithSelector(0xc375ab13);
        // Deploy a campaign
        bytes4 campaignId = bytes4(keccak256("frak.campaign.referral"));
        bytes memory initData = _getReferralCampaignConfigInitData();

        // Deploy the campaign
        vm.startPrank(productOwner);
        address campaign1 = productInteractionManager.deployCampaign(productId, campaignId, initData);
        address campaign2 = productInteractionManager.deployCampaign(productId, campaignId, initData);
        address campaign3 = productInteractionManager.deployCampaign(productId, campaignId, initData);
        address campaign4 = productInteractionManager.deployCampaign(productId, campaignId, initData);
        vm.stopPrank();

        // Perform the interaction and ensure each campaigns is called
        vm.expectCall(campaign1, handleInteractionSelector);
        vm.expectCall(campaign2, handleInteractionSelector);
        vm.expectCall(campaign3, handleInteractionSelector);
        vm.expectCall(campaign4, handleInteractionSelector);
        performSingleInteraction();
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function _getReferralCampaignConfigInitData() internal returns (bytes memory initData) {
        vm.pauseGasMetering();
        ReferralCampaignTriggerConfig[] memory triggers = new ReferralCampaignTriggerConfig[](1);
        triggers[0] = ReferralCampaignTriggerConfig({
            interactionType: ReferralInteractions.REFERRED,
            baseReward: 10 ether,
            userPercent: 5000, // 50%
            deperditionPerLevel: 8000, // 80%
            maxCountPerUser: 1
        });

        ReferralCampaignConfig memory config = ReferralCampaignConfig({
            name: "test",
            triggers: triggers,
            capConfig: ReferralCampaign.CapConfig({period: uint48(0), amount: uint208(0)}),
            activationPeriod: ReferralCampaign.ActivationPeriod({start: uint48(0), end: uint48(0)}),
            campaignBank: campaignBank
        });
        initData = abi.encode(config);
        vm.resumeGasMetering();
    }
}
