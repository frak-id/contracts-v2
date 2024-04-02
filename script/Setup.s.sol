// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { ContentRegistry, Metadata } from "src/tokens/ContentRegistry.sol";
import { PaywallFrk } from "src/tokens/PaywallFrk.sol";
import { Paywall } from "src/Paywall.sol";
import { MINTER_ROLES } from "src/utils/Roles.sol";

contract Setup is Script {

    function run() public {
        console.log("Current address: %s", address(this));
        address airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;
        address owner = 0x7caF754C934710D7C73bc453654552BEcA38223F;
        deploy(airdropper, owner);
    }

    function deploy(address airdropper, address owner) internal {
        vm.startBroadcast();

        PaywallFrk pFrk = new PaywallFrk{ salt: 0 }(owner);
        ContentRegistry contentRegistry = new ContentRegistry{ salt: 0 }(owner);

        Paywall paywall = new Paywall{ salt: 0 }(address(pFrk), address(contentRegistry));

        // Log every deployed address
        console.log("PaywallFrk: %s", address(pFrk));
        console.log("ContentRegistry: %s", address(contentRegistry));
        console.log("Paywall: %s", address(paywall));

        // Grant the minter roles to the airdropper
        pFrk.grantRoles(airdropper, MINTER_ROLES);

        // Then mint the contents
        uint256 cLeMonde = _mintContent(contentRegistry, "Le Monde", "news-example.frak.id");
        uint256 cLequipe = _mintContent(contentRegistry, "L'equipe", "news-example.frak.id");
        uint256 cWired = _mintContent(contentRegistry, "Wired", "news-example.frak.id");

        // And add the prices
        _addTestPrices(paywall, cLeMonde);
        _addTestPrices(paywall, cLequipe);
        _addTestPrices(paywall, cWired);

        vm.stopBroadcast();
    }

    /// @dev Mint a content with the given name and domain
    function _mintContent(ContentRegistry _contentRegistry, string memory _name, string memory _domain) internal returns (uint256) {
        Metadata memory metadata = Metadata(_name, keccak256(bytes(_domain)));
        bytes memory metadataBytes = abi.encode(metadata);
        return _contentRegistry.mint(metadataBytes);
    }

    /// @dev Add test prices to the given content
    function _addTestPrices(Paywall _paywall, uint256 _contentId) internal {
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(50 ether, 1 days, true));
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(300 ether, 7 days, true));
        _paywall.addPrice(_contentId, Paywall.UnlockPrice(1000 ether, 30 days, true));
    }
}