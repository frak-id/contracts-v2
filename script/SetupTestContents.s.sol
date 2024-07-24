// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {
    CONTENT_TYPE_DAPP,
    CONTENT_TYPE_FEATURE_REFERRAL,
    CONTENT_TYPE_PRESS,
    ContentTypes
} from "src/constants/ContentTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {Paywall} from "src/gating/Paywall.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {CommunityToken} from "src/tokens/CommunityToken.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

contract SetupTestContents is Script, DeterminedAddress {
    address internal interactionValidator = 0x8747C17970464fFF597bd5a580A72fCDA224B0A1;

    function run() public {
        Addresses memory addresses = _getAddresses();
        ContentRegistry contentRegistry = ContentRegistry(addresses.contentRegistry);
        Paywall paywall = Paywall(addresses.paywall);
        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        // Mint the contents
        uint256[] memory contentIds = _mintContents(contentRegistry);

        // Setup the paywall for the news example website
        _setupPaywall(paywall, _getContentIds().cNewsExample);

        // Setup the community tokens
        _setupCommunityTokens(CommunityToken(addresses.communityToken), contentIds);

        // Setup the interactions
        _setupInteractions(contentInteractionManager, contentIds);

        _setupCampaigns(contentInteractionManager, addresses, contentIds);
    }

    /// @dev Mint the test contents
    function _mintContents(ContentRegistry contentRegistry) internal returns (uint256[] memory contentIds) {
        contentIds = new uint256[](2);
        vm.startBroadcast();

        // Mint the tests contents
        uint256 cEthccDemo = _mintContent(
            contentRegistry,
            CONTENT_TYPE_PRESS | CONTENT_TYPE_DAPP | CONTENT_TYPE_FEATURE_REFERRAL,
            "Frak - EthCC demo",
            "ethcc.news-paper.xyz"
        );
        uint256 cNewsExample = _mintContent(
            contentRegistry,
            CONTENT_TYPE_PRESS | CONTENT_TYPE_FEATURE_REFERRAL,
            "Frak - Gating Example",
            "news-example.frak.id"
        );
        uint256 cNewsPaper = _mintContent(
            contentRegistry, CONTENT_TYPE_PRESS | CONTENT_TYPE_FEATURE_REFERRAL, "A Positivie World", "news-paper.xyz"
        );
        vm.stopBroadcast();

        console.log("Content id:");
        console.log(" - News-Paper: %s", cNewsPaper); // 20376791661718660580662410765070640284736320707848823176694931891585259913409
        console.log(" - News-Example: %s", cNewsExample); // 8073960722007594212918575991467917289452723924551607525414094759273404023523
        console.log(" - EthCC demo: %s", cEthccDemo); // 33953649417576654953995537313820306697747390492794311279756157547821320957282

        contentIds[0] = cNewsExample;
        contentIds[1] = cEthccDemo;
        contentIds[2] = cNewsPaper;
    }

    /// @dev Mint a content with the given name and domain
    function _mintContent(
        ContentRegistry _contentRegistry,
        ContentTypes _contentTypes,
        string memory _name,
        string memory _domain
    ) internal returns (uint256) {
        return _contentRegistry.mint(_contentTypes, _name, _domain, contentOwner);
    }

    /// @dev Setup the paywall for the given contents
    function _setupPaywall(Paywall _paywall, uint256 _contentId) internal {
        console.log("Setting up paywall");

        vm.startBroadcast();
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(50 ether, 1 days, true));
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(300 ether, 7 days, true));
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(1000 ether, 30 days, true));
        vm.stopBroadcast();
    }

    /// @dev Setup the paywall for the given contents
    function _setupCommunityTokens(CommunityToken _communityToken, uint256[] memory _contentIds) internal {
        console.log("Setting up community tokens");
        vm.startBroadcast();
        for (uint256 i = 0; i < _contentIds.length; i++) {
            _communityToken.allowCommunityToken(_contentIds[i]);
        }
        vm.stopBroadcast();
    }

    /// @dev Setup the paywall for the given contents
    function _setupInteractions(ContentInteractionManager _interactionManager, uint256[] memory _contentIds) internal {
        console.log("Setting up interactions");
        vm.startBroadcast();
        for (uint256 i = 0; i < _contentIds.length; i++) {
            // Deploy the interaction contract
            _interactionManager.deployInteractionContract(_contentIds[i]);
            // Grant the right roles
            _grantValidatorRole(_interactionManager, _contentIds[i]);
        }
        vm.stopBroadcast();
    }

    /// @dev Mint a content with the given name and domain
    function _grantValidatorRole(ContentInteractionManager _interactionManager, uint256 _contentId) internal {
        ContentInteractionDiamond interactionContract = _interactionManager.getInteractionContract(_contentId);
        interactionContract.grantRoles(interactionValidator, INTERCATION_VALIDATOR_ROLE);
    }

    bytes4 private constant REFERRAL_CAMPAIGN_IDENTIFIER = bytes4(keccak256("frak.campaign.referral"));

    /// @dev Setup the paywall for the given contents
    function _setupCampaigns(
        ContentInteractionManager _interactionManager,
        Addresses memory addresses,
        uint256[] memory _contentIds
    ) internal {
        console.log("Setting up campaigns");
        for (uint256 i = 0; i < _contentIds.length; i++) {
            uint256 contentId = _contentIds[i];

            vm.startBroadcast();

            address campaign = _interactionManager.deployCampaign(
                contentId, REFERRAL_CAMPAIGN_IDENTIFIER, _campaignDeploymentData(addresses)
            );

            // Add a few mUSD to the deployed campaign
            mUSDToken(addresses.mUSDToken).mint(address(campaign), 100_000 ether);

            vm.stopBroadcast();
        }
    }

    function _campaignDeploymentData(Addresses memory addresses) private pure returns (bytes memory) {
        ReferralCampaign.CampaignConfig memory config = ReferralCampaign.CampaignConfig({
            token: addresses.mUSDToken,
            initialReward: 10 ether,
            userRewardPercent: 5_000, // 50%
            distributionCapPeriod: 1 days,
            distributionCap: 500 ether,
            startDate: uint48(0),
            endDate: uint48(0)
        });

        return abi.encode(config);
    }
}
