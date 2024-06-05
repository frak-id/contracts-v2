// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {Paywall} from "src/gating/Paywall.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

contract SetupTestContents is Script, DeterminedAddress {
    function run() public {
        setupContents();
    }

    function setupContents() internal {
        ContentRegistry contentRegistry = ContentRegistry(_getAddresses().contentRegistry);
        Paywall paywall = Paywall(_getAddresses().paywall);
        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(_getAddresses().contentInteractionManager);

        vm.startBroadcast();

        // Mint the tests contents
        uint256 cLeMonde =
            _mintContent(contentRegistry, CONTENT_TYPE_PRESS, "Le Monde", "news-example.frak.id/le-monde");
        uint256 cLequipe = _mintContent(contentRegistry, CONTENT_TYPE_PRESS, "L'equipe", "news-example.frak.id/lequipe");
        uint256 cWired = _mintContent(contentRegistry, CONTENT_TYPE_PRESS, "Wired", "news-example.frak.id/wired");
        uint256 cFrak = _mintContent(contentRegistry, CONTENT_TYPE_PRESS, "Frak", "news-paper.xyz");

        console.log("Content id:");
        console.log(" - Le Monde: %s", cLeMonde); // 106219508196454080375526586478153583586194937194493887259467424694676997453395
        console.log(" - L'equipe: %s", cLequipe); // 108586150798115180574743190405367285583167702751783717273705027881651322809951
        console.log(" - Wired: %s", cWired); // 61412812549033025435811962204424170589965658763482764336017940556663446417829
        console.log(" - Frak: %s", cFrak); // 20376791661718660580662410765070640284736320707848823176694931891585259913409

        // Add a few the prices for the gating providers
        _addTestPrices(paywall, cLeMonde);
        _addTestPrices(paywall, cLequipe);
        _addTestPrices(paywall, cWired);
        _addTestPrices(paywall, cFrak);

        // Deploy the interaction contracts
        contentInteractionManager.deployInteractionContract(cLeMonde);
        contentInteractionManager.deployInteractionContract(cLequipe);
        contentInteractionManager.deployInteractionContract(cWired);
        contentInteractionManager.deployInteractionContract(cFrak);

        vm.stopBroadcast();
    }

    /// @dev Mint a content with the given name and domain
    function _mintContent(
        ContentRegistry _contentRegistry,
        ContentTypes _contentTypes,
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
