// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CampaignFactory} from "src/campaign/CampaignFactory.sol";
import {CAMPAIGN_MANAGER_ROLE, MINTER_ROLE, REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

contract Deploy is Script, DeterminedAddress {
    bool internal forceDeploy = vm.envOr("FORCE_DEPLOY", false);

    function run() public {
        console.log("Starting deployment");
        console.log(" - Chain: %s", block.chainid);
        console.log(" - Sender: %s", msg.sender);
        console.log(" - Force deploy: %s", forceDeploy);
        console.log();

        // The pre computed contract addresses
        Addresses memory addresses = _getAddresses();

        addresses = _deployCore(addresses);
        addresses = _deployTokens(addresses);

        // Log every deployed address
        console.log();
        console.log("Deployed all contracts");
        console.log("Addresses:");
        console.log(" - ContentRegistry: %s", addresses.contentRegistry);
        console.log(" - ReferralRegistry: %s", addresses.referralRegistry);
        console.log(" - ContentInteractionManager: %s", addresses.contentInteractionManager);
        console.log(" - FacetFactory: %s", addresses.facetFactory);
        console.log(" - CampaignFactory: %s", addresses.campaignFactory);
        console.log(" - MUSDToken: %s", addresses.mUSDToken);
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
        if (addresses.productAdministratorlRegistry.code.length == 0 || forceDeploy) {
            console.log("Deploying ProductAdministratorRegistry");
            ProductAdministratorRegistry adminRegistry =
                new ProductAdministratorRegistry{salt: 0}(ContentRegistry(addresses.contentRegistry));
            addresses.productAdministratorlRegistry = address(adminRegistry);
        }

        // Deploy the facet factory
        if (addresses.facetFactory.code.length == 0 || forceDeploy) {
            console.log("Deploying InteractionFacetsFactory");
            InteractionFacetsFactory facetFactory = new InteractionFacetsFactory{salt: 0}(
                ReferralRegistry(addresses.referralRegistry),
                ContentRegistry(addresses.contentRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorlRegistry)
            );
            addresses.facetFactory = address(facetFactory);
        }

        // Deploy the campaign factory
        if (addresses.campaignFactory.code.length == 0 || forceDeploy) {
            console.log("Deploying CampaignFactory");
            CampaignFactory campaignFactory = new CampaignFactory{salt: 0}(
                ReferralRegistry(addresses.referralRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorlRegistry),
                airdropper
            );
            addresses.campaignFactory = address(campaignFactory);
        }

        // Deploy the interaction manager if needed
        if (addresses.contentInteractionManager.code.length == 0 || forceDeploy) {
            console.log("Deploying ContentInteractionManager under erc1967 proxy");
            // Dpeloy implem
            address implem = address(
                new ContentInteractionManager{salt: 0}(
                    ContentRegistry(addresses.contentRegistry),
                    ReferralRegistry(addresses.referralRegistry),
                    ProductAdministratorRegistry(addresses.productAdministratorlRegistry)
                )
            );
            // Deploy and register proxy
            address proxy = LibClone.deployDeterministicERC1967(implem, 0);
            ContentInteractionManager(proxy).init(
                msg.sender, InteractionFacetsFactory(addresses.facetFactory), CampaignFactory(addresses.campaignFactory)
            );
            addresses.contentInteractionManager = proxy;

            // Granr it the role to grant tree access on the referral registry
            ReferralRegistry(addresses.referralRegistry).grantRoles(proxy, REFERRAL_ALLOWANCE_MANAGER_ROLE);
        }

        vm.stopBroadcast();
        return addresses;
    }

    function _deployTokens(Addresses memory addresses) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the mUSD token if not already deployed
        if (addresses.mUSDToken.code.length == 0 || forceDeploy) {
            console.log("Deploying mUSDToken");
            mUSDToken mUSD = new mUSDToken{salt: 0}(msg.sender);
            mUSD.grantRoles(airdropper, MINTER_ROLE);
            addresses.mUSDToken = address(mUSD);
        }
        vm.stopBroadcast();
        return addresses;
    }
}
