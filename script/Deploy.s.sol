// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ContentRegistry, Metadata} from "src/tokens/ContentRegistry.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";
import {CommunityToken} from "src/tokens/CommunityToken.sol";
import {Paywall} from "src/Paywall.sol";
import {MINTER_ROLES} from "src/utils/Roles.sol";

contract Deploy is Script {
    address TOKEN_ADDRESS = 0x9584A61F70cC4BEF5b8B5f588A1d35740f0C7ae2;
    address CONTENT_REGISTRY_ADDRESS = 0xD4BCd67b1C62aB27FC04FBd49f3142413aBFC753;
    address PAYWALL_ADDRESS = 0x9218521020EF26924B77188f4ddE0d0f7C405f21;
    address COMMUNITY_TOKEN_ADDRESS = 0xD2849EB12DAcACB4940063007CCbC325cBBb290d;

    function run() public {
        address airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;
        address owner = 0x7caF754C934710D7C73bc453654552BEcA38223F;
        deploy(airdropper, owner);
    }

    function deploy(address airdropper, address owner) internal {
        vm.startBroadcast();

        // Deploy the paywall token if not already deployed
        PaywallToken pFrk;
        if (TOKEN_ADDRESS.code.length == 0) {
            console.log("Deploying PaywallToken");
            pFrk = new PaywallToken{salt: 0}(owner);
            pFrk.grantRoles(airdropper, MINTER_ROLES);
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

        // Deploy the community token factory
        CommunityToken communityToken;
        if (COMMUNITY_TOKEN_ADDRESS.code.length == 0) {
            console.log("Deploying Community token");
            communityToken = new CommunityToken{salt: 0}(contentRegistry);
        } else {
            communityToken = CommunityToken(COMMUNITY_TOKEN_ADDRESS);
        }

        // Log every deployed address
        console.log("Chain: %s", block.chainid);
        console.log(" - PaywallToken: %s", address(pFrk));
        console.log(" - ContentRegistry: %s", address(contentRegistry));
        console.log(" - Paywall: %s", address(paywall));
        console.log(" - Community token: %s", address(communityToken));

        vm.stopBroadcast();
    }
}
