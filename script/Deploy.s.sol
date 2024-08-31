// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";

import "forge-std/Script.sol";

import {stdJson} from "forge-std/StdJson.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CampaignFactory} from "src/campaign/CampaignFactory.sol";
import {CAMPAIGN_MANAGER_ROLE, MINTER_ROLE, REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

contract Deploy is Script, DeterminedAddress {
    using stdJson for string;

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
        console.log(" - ProductRegistry: %s", addresses.productRegistry);
        console.log(" - ReferralRegistry: %s", addresses.referralRegistry);
        console.log(" - ProductAdministratorRegistry: %s", addresses.productAdministratorlRegistry);
        console.log(" - ProductInteractionManager: %s", addresses.productInteractionManager);
        console.log(" - FacetFactory: %s", addresses.facetFactory);
        console.log(" - CampaignFactory: %s", addresses.campaignFactory);
        console.log(" - MUSDToken: %s", addresses.mUSDToken);

        // Save the addresses in a json file
        string memory jsonKey = "ADDRESSES_JSON";
        vm.serializeAddress(jsonKey, "productRegistry", addresses.productRegistry);
        vm.serializeAddress(jsonKey, "referralRegistry", addresses.referralRegistry);
        vm.serializeAddress(jsonKey, "productAdministratorlRegistry", addresses.productAdministratorlRegistry);
        vm.serializeAddress(jsonKey, "productInteractionManager", addresses.productInteractionManager);
        vm.serializeAddress(jsonKey, "facetFactory", addresses.facetFactory);
        vm.serializeAddress(jsonKey, "campaignFactory", addresses.campaignFactory);
        string memory finalJson = vm.serializeAddress(jsonKey, "mUSDToken", addresses.mUSDToken);

        vm.writeJson(finalJson, "./external/addresses.json");
    }

    /// @dev Deploy core ecosystem stuff (ProductRegistry, Community token)
    function _deployCore(Addresses memory addresses) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the registries
        if (addresses.productRegistry.code.length == 0 || forceDeploy) {
            console.log("Deploying ProductRegistry");
            ProductRegistry productRegistry = new ProductRegistry{salt: 0}(msg.sender);
            addresses.productRegistry = address(productRegistry);
        }
        if (addresses.referralRegistry.code.length == 0 || forceDeploy) {
            console.log("Deploying ReferralRegistry");
            ReferralRegistry referralRegistry = new ReferralRegistry{salt: 0}(msg.sender);
            addresses.referralRegistry = address(referralRegistry);
        }
        if (addresses.productAdministratorlRegistry.code.length == 0 || forceDeploy) {
            console.log("Deploying ProductAdministratorRegistry");
            ProductAdministratorRegistry adminRegistry =
                new ProductAdministratorRegistry{salt: 0}(ProductRegistry(addresses.productRegistry));
            addresses.productAdministratorlRegistry = address(adminRegistry);
        }

        // Deploy the facet factory
        if (addresses.facetFactory.code.length == 0 || forceDeploy) {
            console.log("Deploying InteractionFacetsFactory");
            InteractionFacetsFactory facetFactory = new InteractionFacetsFactory{salt: 0}(
                ReferralRegistry(addresses.referralRegistry),
                ProductRegistry(addresses.productRegistry),
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
        if (addresses.productInteractionManager.code.length == 0 || forceDeploy) {
            console.log("Deploying ProductInteractionManager under erc1967 proxy");
            // Dpeloy implem
            address implem = address(
                new ProductInteractionManager{salt: 0}(
                    ProductRegistry(addresses.productRegistry),
                    ReferralRegistry(addresses.referralRegistry),
                    ProductAdministratorRegistry(addresses.productAdministratorlRegistry)
                )
            );
            // Deploy and register proxy
            address proxy = LibClone.deployDeterministicERC1967(implem, 0);
            ProductInteractionManager(proxy).init(
                msg.sender, InteractionFacetsFactory(addresses.facetFactory), CampaignFactory(addresses.campaignFactory)
            );
            addresses.productInteractionManager = proxy;

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
