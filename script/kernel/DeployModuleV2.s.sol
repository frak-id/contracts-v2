// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DeterminedAddress, KernelAddresses} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {InteractionDelegator} from "src/kernel/v2/InteractionDelegator.sol";
import {InteractionDelegatorAction} from "src/kernel/v2/InteractionDelegatorAction.sol";
import {InteractionDelegatorValidator} from "src/kernel/v2/InteractionDelegatorValidator.sol";
import {MultiWebAuthNRecoveryAction} from "src/kernel/v2/MultiWebAuthNRecoveryAction.sol";
import {MultiWebAuthNValidatorV2} from "src/kernel/v2/MultiWebAuthNValidator.sol";

contract DeployModuleV2 is Script, DeterminedAddress {
    bool internal forceDeploy = vm.envOr("FORCE_DEPLOY", false);

    function run() public {
        deploy();
        deployInteractions();
    }

    function deploy() internal {
        KernelAddresses memory addresses = _getKernelAddresses();
        vm.startBroadcast();

        // Deploy the p256 wrapper if not already deployed
        P256VerifierWrapper p256verifierWrapper;
        if (addresses.p256Wrapper.code.length == 0) {
            console.log("Deploying p256 wrapper");
            p256verifierWrapper = new P256VerifierWrapper{salt: 0}();
        } else {
            p256verifierWrapper = P256VerifierWrapper(addresses.p256Wrapper);
        }

        // Deploy the multi webauthn validator if not already deployed
        MultiWebAuthNValidatorV2 multiWebAuthNSigner;
        if (addresses.webAuthNValidator.code.length == 0 || forceDeploy) {
            console.log("Deploying MultiWebAuthNValidator");
            multiWebAuthNSigner = new MultiWebAuthNValidatorV2{salt: 0}(address(p256verifierWrapper));
        } else {
            multiWebAuthNSigner = MultiWebAuthNValidatorV2(addresses.webAuthNValidator);
        }

        // Deploy the multi webauthn validator if not already deployed
        MultiWebAuthNRecoveryAction multiWebAuthNRecovery;
        if (addresses.webAuthNRecoveryAction.code.length == 0 || forceDeploy) {
            console.log("Deploying MultiWebAuthNRecoveryAction");
            multiWebAuthNRecovery = new MultiWebAuthNRecoveryAction{salt: 0}(address(multiWebAuthNSigner));
        } else {
            multiWebAuthNRecovery = MultiWebAuthNRecoveryAction(addresses.webAuthNRecoveryAction);
        }

        // Log every deployed address
        console.log("Chain: %s", block.chainid);
        console.log(" - P256VerifierWrapper: %s", address(p256verifierWrapper));
        console.log(" - MultiWebAuthNValidator: %s", address(multiWebAuthNSigner));
        console.log(" - MultiWebAuthNRecoveryAction: %s", address(multiWebAuthNRecovery));

        vm.stopBroadcast();
    }

    function deployInteractions() internal {
        KernelAddresses memory addresses = _getKernelAddresses();
        vm.startBroadcast();

        // Deploy the interaction delegator if not already deployed
        InteractionDelegator interactionDelegator;
        if (addresses.interactionDelegator.code.length == 0 || forceDeploy) {
            console.log("Deploying InteractionDelegator");
            interactionDelegator = new InteractionDelegator{salt: 0}(msg.sender);
        } else {
            interactionDelegator = InteractionDelegator(payable(addresses.interactionDelegator));
        }

        // Deploy the interaction delegator validator if not already deployed
        InteractionDelegatorValidator interactionDelegatorValidator;
        if (addresses.interactionDelegatorValidator.code.length == 0 || forceDeploy) {
            console.log("Deploying InteractionDelegatorValidator");
            interactionDelegatorValidator = new InteractionDelegatorValidator{salt: 0}(address(interactionDelegator));
        } else {
            interactionDelegatorValidator = InteractionDelegatorValidator(addresses.interactionDelegatorValidator);
        }

        // Deploy the interaction delegator action if not already deployed
        InteractionDelegatorAction interactionDelegatorAction;
        if (addresses.interactionDelegatorAction.code.length == 0 || forceDeploy) {
            console.log("Deploying InteractionDelegatorAction");
            interactionDelegatorAction = new InteractionDelegatorAction{salt: 0}(
                ProductInteractionManager(_getAddresses().productInteractionManager)
            );
        } else {
            interactionDelegatorAction = InteractionDelegatorAction(addresses.interactionDelegatorAction);
        }

        // Log every deployed address
        console.log("Chain: %s", block.chainid);
        console.log(" - InteractionDelegator: %s", address(interactionDelegator));
        console.log(" - InteractionDelegatorValidator: %s", address(interactionDelegatorValidator));
        console.log(" - InteractionDelegatorAction: %s", address(interactionDelegatorAction));

        vm.stopBroadcast();
    }
}
