// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DeterminedAddress, KernelAddresses} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {DELEGATION_EXECUTOR_ROLE, InteractionDelegator} from "src/kernel/interaction/InteractionDelegator.sol";

contract AddInteractionExecutor is Script, DeterminedAddress {
    address private operator = 0xDd2926b47A2ea470632a45143CB2b45d4b1B60eC;

    function run() public {
        KernelAddresses memory addresses = _getKernelAddresses();

        InteractionDelegator interactionDelegator = InteractionDelegator(payable(addresses.interactionDelegator));

        _addExecutor(interactionDelegator);
    }

    function _addExecutor(InteractionDelegator _interactionDelegator) internal {
        vm.startBroadcast();
        _interactionDelegator.grantRoles(operator, DELEGATION_EXECUTOR_ROLE);
        vm.stopBroadcast();
    }
}
