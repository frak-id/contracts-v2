// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CommunityToken} from "src/tokens/CommunityToken.sol";

contract SetupPaywall is Script {
    address COMMUNITY_TOKEN_communityToken_ADDRESS = 0xf98BA1b2fc7C55A01Efa6C8872Bcee85c6eC54e7;

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
