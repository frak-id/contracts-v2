// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DeterminedAddress, KernelAddresses} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {DELEGATION_EXECUTOR_ROLE, InteractionDelegator} from "src/kernel/interaction/InteractionDelegator.sol";

contract AddInteractionExecutor is Script, DeterminedAddress {
    address private operatorLocal = 0x0612994c389F253f22AF91B63DD622049b7D42C5;
    address private operatorDev = 0xef33C59086808F63733C3b92d273930772466b08;

    function run() public {
        KernelAddresses memory addresses = _getKernelAddresses();

        InteractionDelegator interactionDelegator = InteractionDelegator(payable(addresses.interactionDelegator));

        _addExecutor(interactionDelegator);
    }

    function _addExecutor(InteractionDelegator _interactionDelegator) internal {
        vm.startBroadcast();
        _interactionDelegator.grantRoles(operatorLocal, DELEGATION_EXECUTOR_ROLE);
        _interactionDelegator.grantRoles(operatorDev, DELEGATION_EXECUTOR_ROLE);
        vm.stopBroadcast();
    }
}
