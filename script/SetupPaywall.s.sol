// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ContentRegistry, Metadata} from "src/registry/ContentRegistry.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";
import {Paywall} from "src/Paywall.sol";
import {CONTENT_TYPE_PRESS} from "src/constants/Contents.sol";

contract SetupPaywall is Script {
    address CONTENT_REGISTRY_ADDRESS = 0xD4BCd67b1C62aB27FC04FBd49f3142413aBFC753;
    address PAYWALL_ADDRESS = 0x9218521020EF26924B77188f4ddE0d0f7C405f21;

    function run() public {
        setupContents();
    }

    function setupContents() internal {
        vm.startBroadcast();

        ContentRegistry contentRegistry = ContentRegistry(CONTENT_REGISTRY_ADDRESS);
        Paywall paywall = Paywall(PAYWALL_ADDRESS);

        // Then mint the contents
        uint256 cLeMonde =
            _mintContent(contentRegistry, CONTENT_TYPE_PRESS, "Le Monde", "news-example.frak.id/le-monde");
        uint256 cLequipe = _mintContent(contentRegistry, CONTENT_TYPE_PRESS, "L'equipe", "news-example.frak.id/lequipe");
        uint256 cWired = _mintContent(contentRegistry, CONTENT_TYPE_PRESS, "Wired", "news-example.frak.id/wired");
        uint256 cFrak = _mintContent(contentRegistry, CONTENT_TYPE_PRESS, "Frak", "news-paper.xyz");

        // And add the prices
        _addTestPrices(paywall, cLeMonde);
        _addTestPrices(paywall, cLequipe);
        _addTestPrices(paywall, cWired);
        _addTestPrices(paywall, cFrak);

        vm.stopBroadcast();
    }

    /// @dev Mint a content with the given name and domain
    function _mintContent(
        ContentRegistry _contentRegistry,
        bytes32 _contentTypes,
        string memory _name,
        string memory _domain
    ) internal returns (uint256) {
        return _contentRegistry.mint(_contentTypes, _name, _domain);
    }

    /// @dev Add test prices to the given content
    function _addTestPrices(Paywall _paywall, uint256 _contentId) internal {
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(50 ether, 1 days, true));
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(300 ether, 7 days, true));
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(1000 ether, 30 days, true));
    }
}
