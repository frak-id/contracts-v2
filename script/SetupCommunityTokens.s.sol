// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentIds, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {CommunityToken} from "src/tokens/CommunityToken.sol";

contract SetupPaywall is Script, DeterminedAddress {
    function run() public {
        setupCommunityTokens();
    }

    function setupCommunityTokens() internal {
        vm.startBroadcast();

        ContentIds memory contentIds = _getContentIds();

        CommunityToken communityToken = CommunityToken(_getAddresses().communityToken);
        communityToken.allowCommunityToken(contentIds.cLeMonde);
        communityToken.allowCommunityToken(contentIds.cLequipe);
        communityToken.allowCommunityToken(contentIds.cWired);
        communityToken.allowCommunityToken(contentIds.cFrak);

        vm.stopBroadcast();
    }
}
