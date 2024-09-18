// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CampaignBank} from "src/campaign/CampaignBank.sol";
import {ReferralCampaignV2} from "src/campaign/ReferralCampaignv2.sol";
import {InteractionTypeLib, ReferralInteractions} from "src/constants/InteractionType.sol";
import {
    PRODUCT_TYPE_DAPP,
    PRODUCT_TYPE_FEATURE_REFERRAL,
    PRODUCT_TYPE_PRESS,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";

contract ReferralCampaignV2Test is EcosystemAwareTest {
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");
    address private delta = makeAddr("delta");

    /// @dev The product interaction contract
    ProductInteractionDiamond private productInteraction;

    /// @dev The product id
    uint256 private productId;
    bytes32 private referralTree;

    /// @dev The bank we will use
    CampaignBank private campaignBank;

    /// @dev The campaign we will test
    ReferralCampaignV2 private referralCampaign;

    function setUp() public {
        _initEcosystemAwareTest();

        // Setup content with allowance for the operator
        (productId, productInteraction) = _mintProductWithInteraction(PRODUCT_TYPE_PRESS, "name", "press-domain");

        // Get the referral tree
        referralTree = productInteraction.getReferralTree();

        // Deploy the bank
        campaignBank = new CampaignBank(adminRegistry, productId, address(token));

        // Mint a few test tokens to the campaign
        token.mint(address(campaignBank), 1_000 ether);

        // Start our bank
        vm.prank(productOwner);
        campaignBank.updateDistributionState(true);

        // Grant the right roles to the product interaction manager
        vm.prank(owner);
        referralRegistry.grantAccessToTree(referralTree, owner);

        // Fake the timestamp
        vm.warp(100);
    }

    function test_init() public pure {
        assertTrue(true);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    modifier withReferralChain() {
        vm.startPrank(owner);
        referralRegistry.saveReferrer(referralTree, alice, bob);
        referralRegistry.saveReferrer(referralTree, bob, charlie);
        referralRegistry.saveReferrer(referralTree, charlie, delta);
        vm.stopPrank();
        _;
    }
}
