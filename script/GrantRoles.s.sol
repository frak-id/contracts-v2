// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {COMPLIANCE_ROLE, REWARDER_ROLE} from "src/constants/Roles.sol";
import {RewarderHub} from "src/reward/RewarderHub.sol";

/// @dev Grant the roles to the frak contracts
/// @author @KONFeature
contract GrantRoles is Script, DeterminedAddress {
    using stdJson for string;

    address internal rewarder = vm.envOr("REWARDER_WALLET", address(0));
    address internal compliance = vm.envOr("COMPLIANCE_WALLET", address(0));

    function run() public {
        console.log("Starting roles set");
        console.log(" - Chain: %s", block.chainid);
        console.log(" - Sender: %s", msg.sender);
        console.log(" - Rewarder: %s", rewarder);
        console.log();

        // The pre computed contract addresses
        Addresses memory addresses = _getAddresses();

        // Get our rewarder hub
        RewarderHub rewarderHub = RewarderHub(addresses.rewarderHub);

        // Grant the roles to the defined rewarder
        vm.startBroadcast();
        rewarderHub.grantRoles(rewarder, REWARDER_ROLE);
        rewarderHub.grantRoles(compliance, COMPLIANCE_ROLE);
        vm.stopBroadcast();
    }
}
