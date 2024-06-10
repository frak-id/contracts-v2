// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CAMPAIGN_MANAGER_ROLE, MINTER_ROLE, REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {Paywall} from "src/gating/Paywall.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {CommunityToken} from "src/tokens/CommunityToken.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

contract Deploy is Script, DeterminedAddress {
    bool internal forceDeploy = vm.envOr("FORCE_DEPLOY", false);
    string internal communityBaseUrl = vm.envString("COMMUNITY_TOKEN_BASE_URL_DEPLOY");

    function run() public {
        console.log("Starting deployment");
        console.log(" - Chain: %s", block.chainid);
        console.log(" - Sender: %s", msg.sender);
        console.log(" - Force deploy: %s", forceDeploy);
        console.log(" - Community base url: %s", communityBaseUrl);
        console.log();

        // The pre computed contract addresses
        Addresses memory addresses = _getAddresses();

        addresses = _deployCore(addresses);
        addresses = _deployPaywall(addresses);
        addresses = _deployCommunity(addresses);

        // Log every deployed address
        console.log();
        console.log("Deployed all contracts");
        console.log("Addresses:");
        console.log(" - ContentRegistry: %s", addresses.contentRegistry);
        console.log(" - ReferralRegistry: %s", addresses.referralRegistry);
        console.log(" - ContentInteractionManager: %s", addresses.contentInteractionManager);
        console.log(" - InteractionFacetFactory: %s", addresses.facetFactory);
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
            ContentRegistry contentRegistry = new ContentRegistry{salt: 0}(msg.sender);
            addresses.contentRegistry = address(contentRegistry);
        }
        if (addresses.referralRegistry.code.length == 0 || forceDeploy) {
            console.log("Deploying ReferralRegistry");
            ReferralRegistry referralRegistry = new ReferralRegistry{salt: 0}(msg.sender);
            addresses.referralRegistry = address(referralRegistry);
        }

        // Deploy the facet factory
        if (addresses.facetFactory.code.length == 0 || forceDeploy) {
            console.log("Deploying InteractionFacetsFactory");
            InteractionFacetsFactory facetFactory = new InteractionFacetsFactory{salt: 0}(
                ReferralRegistry(addresses.referralRegistry), ContentRegistry(addresses.contentRegistry)
            );
            addresses.facetFactory = address(facetFactory);
        }

        // Deploy the interaction manager if needed
        if (addresses.contentInteractionManager.code.length == 0 || forceDeploy) {
            console.log("Deploying ContentInteractionManager under erc1967 proxy");
            // Dpeloy implem
            address implem = address(
                new ContentInteractionManager{salt: 0}(
                    ContentRegistry(addresses.contentRegistry), ReferralRegistry(addresses.referralRegistry)
                )
            );
            // Deploy and register proxy
            address proxy = LibClone.deployDeterministicERC1967(implem, 0);
            ContentInteractionManager(proxy).init(msg.sender, InteractionFacetsFactory(addresses.facetFactory));
            addresses.contentInteractionManager = proxy;

            // Granr it the role to grant tree access on the referral registry
            ReferralRegistry(addresses.referralRegistry).grantRoles(proxy, REFERRAL_ALLOWANCE_MANAGER_ROLE);
        }

        vm.stopBroadcast();
        return addresses;
    }

    function _deployPaywall(Addresses memory addresses) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the paywall token if not already deployed
        if (addresses.paywallToken.code.length == 0 || forceDeploy) {
            console.log("Deploying PaywallToken");
            PaywallToken pFrk = new PaywallToken{salt: 0}(msg.sender);
            pFrk.grantRoles(airdropper, MINTER_ROLE);
            addresses.paywallToken = address(pFrk);
        }

        // Deploy paywall if needed
        if (addresses.paywall.code.length == 0 || forceDeploy) {
            console.log("Deploying Paywall");
            Paywall paywall = new Paywall{salt: 0}(addresses.paywallToken, addresses.contentRegistry);
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
            CommunityToken communityToken =
                new CommunityToken{salt: 0}(ContentRegistry(addresses.contentRegistry), communityBaseUrl);
            addresses.communityToken = address(communityToken);
        }

        vm.stopBroadcast();
        return addresses;
    }
}
