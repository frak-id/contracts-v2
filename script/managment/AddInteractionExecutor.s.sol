// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DeterminedAddress, KernelAddresses} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {DELEGATION_EXECUTOR_ROLE, InteractionDelegator} from "src/kernel/v2/InteractionDelegator.sol";

contract AddInteractionExecutor is Script, DeterminedAddress {
    address private operator = airdropper;

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
