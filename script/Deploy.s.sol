// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {Paywall} from "src/Paywall.sol";
import {NexusDiscoverCampaign} from "src/campaign/NexusDiscoverCampaign.sol";

import {CAMPAIGN_MANAGER_ROLE, MINTER_ROLE} from "src/constants/Roles.sol";
import {ContentRegistry, Metadata} from "src/registry/ContentRegistry.sol";
import {CommunityToken} from "src/tokens/CommunityToken.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

import {ReferralToken} from "src/tokens/ReferralToken.sol";

contract Deploy is Script {
    // Config
    address airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;
    address owner = 0x7caF754C934710D7C73bc453654552BEcA38223F;

    // Pre computed address
    address TOKEN_ADDRESS = 0x9584A61F70cC4BEF5b8B5f588A1d35740f0C7ae2;
    address CONTENT_REGISTRY_ADDRESS = 0xD4BCd67b1C62aB27FC04FBd49f3142413aBFC753;
    address PAYWALL_ADDRESS = 0x9218521020EF26924B77188f4ddE0d0f7C405f21;

    address COMMUNITY_TOKEN_ADDRESS = 0xf98BA1b2fc7C55A01Efa6C8872Bcee85c6eC54e7;

    address REFERRAL_TOKEN_ADDRESS = 0x1Eca7AA9ABF2e53E773B4523B6Dc103002d22e7D;
    address NEXUS_DISCOVER_CAMPAIGN_ADDRESS = 0x8a37d1B3a17559F2BC4e6613834b1F13d0A623aC;

    function run() public {
        console.log("Deploying to chain: %s", block.chainid);
        _deployCore();
        _deployCommunity();
        _deployCampaign();
    }

    /// @dev Deploy core ecosystem stuff (ContentRegistry, Community token)
    function _deployCore() internal {
        vm.startBroadcast();

        // Deploy the paywall token if not already deployed
        PaywallToken pFrk;
        if (TOKEN_ADDRESS.code.length == 0) {
            console.log("Deploying PaywallToken");
            pFrk = new PaywallToken{salt: 0}(owner);
            pFrk.grantRoles(airdropper, MINTER_ROLE);
        } else {
            pFrk = PaywallToken(TOKEN_ADDRESS);
        }

        // Deploy the paywall token if not already deployed
        ContentRegistry contentRegistry;
        if (CONTENT_REGISTRY_ADDRESS.code.length == 0) {
            console.log("Deploying ContentRegistry");
            contentRegistry = new ContentRegistry{salt: 0}(owner);
        } else {
            contentRegistry = ContentRegistry(CONTENT_REGISTRY_ADDRESS);
        }

        // Deploy the paywall token if not already deployed
        Paywall paywall;
        if (PAYWALL_ADDRESS.code.length == 0) {
            console.log("Deploying Paywall");
            paywall = new Paywall{salt: 0}(address(pFrk), address(contentRegistry));
        } else {
            paywall = Paywall(PAYWALL_ADDRESS);
        }

        // Log every deployed address
        console.log("Core addresses:");
        console.log(" - PaywallToken: %s", address(pFrk));
        console.log(" - ContentRegistry: %s", address(contentRegistry));
        console.log(" - Paywall: %s", address(paywall));

        vm.stopBroadcast();
    }

    /// @dev Deploy the community related stuff
    function _deployCommunity() internal {
        vm.startBroadcast();

        // Deploy the community token factory
        CommunityToken communityToken;
        if (COMMUNITY_TOKEN_ADDRESS.code.length == 0) {
            console.log("Deploying Community token");
            communityToken = new CommunityToken{salt: 0}(ContentRegistry(CONTENT_REGISTRY_ADDRESS));
        } else {
            communityToken = CommunityToken(COMMUNITY_TOKEN_ADDRESS);
        }

        console.log("Community addresses:");
        console.log(" - Community token: %s", address(communityToken));

        vm.stopBroadcast();
    }

    /// @dev Deploy the campaign related stuff
    function _deployCampaign() internal {
        vm.startBroadcast();

        // Deploy the referral token
        ReferralToken referralToken;
        if (REFERRAL_TOKEN_ADDRESS.code.length == 0) {
            console.log("Deploying Referral token");
            referralToken = new ReferralToken{salt: 0}(owner);
            referralToken.grantRoles(airdropper, MINTER_ROLE);
        } else {
            referralToken = ReferralToken(REFERRAL_TOKEN_ADDRESS);
        }

        // Deploy the discover campaign
        NexusDiscoverCampaign discoverCampaign;
        if (NEXUS_DISCOVER_CAMPAIGN_ADDRESS.code.length == 0) {
            console.log("Deploying Discover campaign");
            discoverCampaign = new NexusDiscoverCampaign{salt: 0}(address(referralToken), owner);
            discoverCampaign.grantRoles(airdropper, CAMPAIGN_MANAGER_ROLE);
        } else {
            discoverCampaign = NexusDiscoverCampaign(NEXUS_DISCOVER_CAMPAIGN_ADDRESS);
        }

        // Perform an airdrop of 50K rFrk to the discover campaign
        referralToken.mint(address(discoverCampaign), 50_000 ether);

        console.log("Campaign addresses:");
        console.log(" - Referral token: %s", address(referralToken));
        console.log(" - Discover campaign: %s", address(discoverCampaign));

        vm.stopBroadcast();
    }
}
