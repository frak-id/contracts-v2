// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Reward system
import {RewarderHub} from "src/reward/RewarderHub.sol";

/// @dev Update/upgrade script for Frak contracts
/// @author @KONFeature
contract Update is Script, DeterminedAddress {
    function run() public {
        console.log("Starting upgrade");
        console.log(" - Chain: %s", block.chainid);
        console.log(" - Sender: %s", msg.sender);
        console.log();

        // Get current addresses
        Addresses memory addresses = _getAddresses();

        // Validate RewarderHub exists
        require(addresses.rewarderHub != address(0), "RewarderHub not deployed - run Deploy.s.sol first");

        vm.startBroadcast();

        // Upgrade RewarderHub
        _upgradeRewarderHub(addresses.rewarderHub);

        vm.stopBroadcast();
    }

    /* -------------------------------------------------------------------------- */
    /*                           RewarderHub Upgrade                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Upgrade the RewarderHub to a new implementation
    function _upgradeRewarderHub(address proxy) internal {
        // Get current implementation for logging
        // ERC1967 implementation slot: bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address currentImpl = address(uint160(uint256(vm.load(proxy, implSlot))));
        console.log(" * Current RewarderHub implementation: %s", currentImpl);

        // Deploy new implementation
        RewarderHub newImplementation =
            new RewarderHub{salt: 0x0000000000000000000000000000000000000000000000000000000000000000}();
        console.log(" * New RewarderHub implementation: %s", address(newImplementation));

        // Upgrade proxy to new implementation (no initialization data needed)
        RewarderHub(proxy).upgradeToAndCall(address(newImplementation), "");

        console.log(" * RewarderHub upgraded successfully");
    }
}
