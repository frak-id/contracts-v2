// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CommunityToken} from "src/tokens/CommunityToken.sol";

contract SetupPaywall is Script {
    address COMMUNITY_TOKEN_communityToken_ADDRESS = 0xD2849EB12DAcACB4940063007CCbC325cBBb290d;

    function run() public {
        setupCommunityTokens();
    }

    function setupCommunityTokens() internal {
        vm.startBroadcast();

        CommunityToken communityToken = CommunityToken(COMMUNITY_TOKEN_communityToken_ADDRESS);
        communityToken.allowCommunityToken(0);
        communityToken.allowCommunityToken(1);
        communityToken.allowCommunityToken(2);

        vm.stopBroadcast();
    }
}
