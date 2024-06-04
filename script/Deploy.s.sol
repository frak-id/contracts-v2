// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {Paywall} from "src/Paywall.sol";
import {CAMPAIGN_MANAGER_ROLE, MINTER_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {CommunityToken} from "src/tokens/CommunityToken.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

contract Deploy is Script {
    // Config
    address airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;
    address owner = 0x7caF754C934710D7C73bc453654552BEcA38223F;

    // Registry addresses
    address constant CONTENT_REGISTRY_ADDRESS = 0x5be7ae9f47dfe007CecA06b299e7CdAcD0A5C40e;
    address constant REFERRAL_REGISTRY_ADDRESS = 0x0a1d4292bC42d39e02b98A6AF9d2E49F16DBED43;

    address constant CONTENT_INTERACTION_MANAGER_ADDRESS = 0x7ce89920844aa49750b03C29aAd74E8e84A9620C;

    address constant PAYWALL_TOKEN_ADDRESS = 0x9584A61F70cC4BEF5b8B5f588A1d35740f0C7ae2;
    address constant PAYWALL_ADDRESS = 0x2Ed88d7A95d687aE262A385DaB7255FA1cA39901;

    address constant COMMUNITY_TOKEN_ADDRESS = 0x581199D05d01B949c91933636EB90014cDB0168c;

    bool internal forceDeploy = vm.envOr("FORCE_DEPLOY", false);

    struct Addresses {
        // Core
        address contentRegistry;
        address referralRegistry;
        address contentInteractionManager;
        // Gating
        address paywallToken;
        address paywall;
        // Community
        address communityToken;
    }

    function run() public {
        console.log("Deploying to chain: %s", block.chainid);

        // The pre computed contract addresses
        Addresses memory addresses = Addresses({
            contentRegistry: 0x5be7ae9f47dfe007CecA06b299e7CdAcD0A5C40e,
            referralRegistry: 0x0a1d4292bC42d39e02b98A6AF9d2E49F16DBED43,
            contentInteractionManager: 0x7ce89920844aa49750b03C29aAd74E8e84A9620C,
            paywallToken: 0x9584A61F70cC4BEF5b8B5f588A1d35740f0C7ae2,
            paywall: 0x2Ed88d7A95d687aE262A385DaB7255FA1cA39901,
            communityToken: 0x581199D05d01B949c91933636EB90014cDB0168c
        });

        addresses = _deployCore(addresses);
        addresses = _deployPaywall(addresses);
        addresses = _deployCommunity(addresses);

        // Log every deployed address
        console.log("Deployed all contracts");
        console.log("Addresses:");
        console.log(" - ContentRegistry: %s", addresses.contentRegistry);
        console.log(" - ReferralRegistry: %s", addresses.referralRegistry);
        console.log(" - ContentInteractionManager: %s", addresses.contentInteractionManager);
        console.log(" - PaywallToken: %s", addresses.paywallToken);
        console.log(" - Paywall: %s", addresses.paywall);
        console.log(" - CommunityToken: %s", addresses.communityToken);
    }

    /// @dev Deploy core ecosystem stuff (ContentRegistry, Community token)
    function _deployCore(Addresses memory addresses) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the registries
        if (addresses.contentRegistry.code.length == 0 || forceDeploy) {
            console.log("Deploying ContentRegistry");
            ContentRegistry contentRegistry = new ContentRegistry{salt: 0}(owner);
            addresses.contentRegistry = address(contentRegistry);
        }
        if (addresses.referralRegistry.code.length == 0 || forceDeploy) {
            console.log("Deploying ReferralRegistry");
            ReferralRegistry referralRegistry = new ReferralRegistry{salt: 0}(owner);
            addresses.referralRegistry = address(referralRegistry);
        }

        // Deploy the interaction manager if needed
        if (addresses.contentInteractionManager.code.length == 0 || forceDeploy) {
            console.log("Deploying ContentInteractionManager under erc1967 proxy");
            // Dpeloy implem
            address implem = address(
                new ContentInteractionManager(
                    ContentRegistry(addresses.contentRegistry), ReferralRegistry(addresses.referralRegistry)
                )
            );
            // Deploy and register proxy
            address proxy = LibClone.deployDeterministicERC1967(implem, 0);
            ContentInteractionManager(proxy).init(owner);
            addresses.contentInteractionManager = proxy;
        }

        vm.stopBroadcast();
        return addresses;
    }

    function _deployPaywall(Addresses memory addresses) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the paywall token if not already deployed
        if (addresses.paywallToken.code.length == 0 || forceDeploy) {
            console.log("Deploying PaywallToken");
            PaywallToken pFrk = new PaywallToken{salt: 0}(owner);
            pFrk.grantRoles(airdropper, MINTER_ROLE);
            addresses.paywallToken = address(pFrk);
        }

        // Deploy paywall if needed
        if (addresses.paywall.code.length == 0 || forceDeploy) {
            console.log("Deploying Paywall");
            Paywall paywall = new Paywall{salt: 0}(addresses.paywallToken, addresses.referralRegistry);
            addresses.paywall = address(paywall);
        }

        vm.stopBroadcast();
        return addresses;
    }

    /// @dev Deploy the community related stuff
    function _deployCommunity(Addresses memory addresses) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the community token factory
        if (addresses.communityToken.code.length == 0 || forceDeploy) {
            console.log("Deploying Community token");
            CommunityToken communityToken = new CommunityToken{salt: 0}(ContentRegistry(addresses.contentRegistry));
            addresses.communityToken = address(communityToken);
        }

        vm.stopBroadcast();
        return addresses;
    }
}
