// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DeterminedAddress} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {InteractionSessionValidator} from "src/kernel/v2/InteractionSessionValidator.sol";
import {MultiWebAuthNRecoveryAction} from "src/kernel/v2/MultiWebAuthNRecoveryAction.sol";
import {MultiWebAuthNValidatorV2} from "src/kernel/v2/MultiWebAuthNValidator.sol";

contract DeployModuleV2 is Script, DeterminedAddress {
    address P256_WRAPPER_ADDRESS = 0x97A24c95E317c44c0694200dd0415dD6F556663D;
    address MULTI_WEBAUTHN_VALIDATOR_ADDRESS = 0xD546c4Ba2e8e5e5c961C36e6Db0460Be03425808;
    address MULTI_WEBAUTHN_VALIDATOR_RECOVERY_ADDRESS = 0x67236B8AAF4B32d2D3269e088B1d43aef7736ab9;
    address INTERACTION_SESSSION_VALIDATOR_ADDRESS = 0x9E0DF410cB5f417642d931e1Aa2b62ECeac0aB15;

    function run() public {
        deploy();
    }

    function deploy() internal {
        vm.startBroadcast();

        // Deploy the p256 wrapper if not already deployed
        P256VerifierWrapper p256verifierWrapper;
        if (P256_WRAPPER_ADDRESS.code.length == 0) {
            console.log("Deploying p256 wrapper");
            p256verifierWrapper = new P256VerifierWrapper{salt: 0}();
        } else {
            p256verifierWrapper = P256VerifierWrapper(P256_WRAPPER_ADDRESS);
        }

        // Deploy the multi webauthn validator if not already deployed
        MultiWebAuthNValidatorV2 multiWebAuthNSigner;
        if (MULTI_WEBAUTHN_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying MultiWebAuthNValidator");
            multiWebAuthNSigner = new MultiWebAuthNValidatorV2{salt: 0}(address(p256verifierWrapper));
        } else {
            multiWebAuthNSigner = MultiWebAuthNValidatorV2(MULTI_WEBAUTHN_VALIDATOR_ADDRESS);
        }

        // Deploy the multi webauthn validator if not already deployed
        MultiWebAuthNRecoveryAction multiWebAuthNRecovery;
        if (MULTI_WEBAUTHN_VALIDATOR_RECOVERY_ADDRESS.code.length == 0) {
            console.log("Deploying MultiWebAuthNRecoveryAction");
            multiWebAuthNRecovery = new MultiWebAuthNRecoveryAction{salt: 0}(address(multiWebAuthNSigner));
        } else {
            multiWebAuthNRecovery = MultiWebAuthNRecoveryAction(MULTI_WEBAUTHN_VALIDATOR_RECOVERY_ADDRESS);
        }

        // Deploy the interaction session validator if not already deployed
        InteractionSessionValidator interactionValidator;
        if (INTERACTION_SESSSION_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying InteractionSessionValidator");
            interactionValidator = new InteractionSessionValidator{salt: 0}(
                ContentInteractionManager(_getAddresses().contentInteractionManager)
            );
        } else {
            interactionValidator = InteractionSessionValidator(INTERACTION_SESSSION_VALIDATOR_ADDRESS);
        }

        // Log every deployed address
        console.log("Chain: %s", block.chainid);
        console.log(" - P256VerifierWrapper: %s", address(p256verifierWrapper));
        console.log(" - MultiWebAuthNValidator: %s", address(multiWebAuthNSigner));
        console.log(" - MultiWebAuthNRecoveryAction: %s", address(multiWebAuthNRecovery));
        console.log(" - InteractionSessionValidator: %s", address(interactionValidator));

        vm.stopBroadcast();
    }
}
