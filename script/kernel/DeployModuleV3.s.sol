// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {MultiWebAuthNRecovery} from "src/kernel/v3/MultiWebAuthNRecovery.sol";
import {MultiWebAuthNValidatorV3} from "src/kernel/v3/MultiWebAuthNValidator.sol";
import {NexusFactory} from "src/kernel/v3/NexusFactory.sol";
import {RecoveryPolicy} from "src/kernel/v3/RecoveryPolicy.sol";
import {WebAuthNValidatorV3} from "src/kernel/v3/WebAuthNValidator.sol";

contract DeployModuleV3 is Script {
    // Validator themself
    address P256_WRAPPER_ADDRESS = 0x97A24c95E317c44c0694200dd0415dD6F556663D;
    address WEBAUTHN_VALIDATOR_ADDRESS = 0x2563cEd40Af6f51A3dF0F1b58EF4Cf1B994fDe12;
    address MULTI_WEBAUTHN_VALIDATOR_ADDRESS = 0x93228CA325349FC7d8C397bECc0515e370aa4555;

    // Factory
    address NEXUS_FACTORY_ADDRESS = 0x304bf281a28e451FbCd53FeDb0672b6021E6C40D;

    // Recovery stuff
    address RECOVERY_POLICY_ADDRESS = 0xD0b868A455d39be41f6f4bEb1efe3912966e8233;
    address RECOVERY_ACTION_ADDRESS = 0x518B5EFB2A2A3c1D408b8aE60A2Ba8D6d264D7BA;

    // The current kernel logic address
    address KERNEL_LOGIC_3_0_ADDRESS = 0x94F097E1ebEB4ecA3AAE54cabb08905B239A7D27;

    function run() public {
        console.log("Chain: %s", block.chainid);
        _deployValidator();
        _deployFactory();
        _deployRecovery();
    }

    /// @dev Deploy all of the validator
    function _deployValidator() internal {
        vm.startBroadcast();

        // Deploy the p256 wrapper if not already deployed
        P256VerifierWrapper p256verifierWrapper;
        if (P256_WRAPPER_ADDRESS.code.length == 0) {
            console.log("Deploying p256 wrapper");
            p256verifierWrapper = new P256VerifierWrapper{salt: 0}();
        } else {
            p256verifierWrapper = P256VerifierWrapper(P256_WRAPPER_ADDRESS);
        }

        // Deploy the webauthn validator if not already deployed
        WebAuthNValidatorV3 webAuthNSigner;
        if (WEBAUTHN_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying WebAuthNValidatorV3");
            webAuthNSigner = new WebAuthNValidatorV3{salt: 0}(address(p256verifierWrapper));
        } else {
            webAuthNSigner = WebAuthNValidatorV3(WEBAUTHN_VALIDATOR_ADDRESS);
        }

        // Deploy the multi webauthn validator if not already deployed
        MultiWebAuthNValidatorV3 multiWebAuthNSigner;
        if (MULTI_WEBAUTHN_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying MultiWebAuthNValidator");
            multiWebAuthNSigner = new MultiWebAuthNValidatorV3{salt: 0}(address(p256verifierWrapper));
        } else {
            multiWebAuthNSigner = MultiWebAuthNValidatorV3(MULTI_WEBAUTHN_VALIDATOR_ADDRESS);
        }

        // Log every deployed address
        console.log(" - P256VerifierWrapper: %s", address(p256verifierWrapper));
        console.log(" - WebAuthNValidatorV3: %s", address(webAuthNSigner));
        console.log(" - MultiWebAuthNValidatorV3: %s", address(multiWebAuthNSigner));

        vm.stopBroadcast();
    }

    /// @dev Deploy the nexus factory
    function _deployFactory() internal {
        vm.startBroadcast();

        // Deploy the factory if not already deployed
        NexusFactory factory;
        if (NEXUS_FACTORY_ADDRESS.code.length == 0) {
            console.log("Deploying NexusFactory");
            factory = new NexusFactory{salt: 0}(KERNEL_LOGIC_3_0_ADDRESS, MULTI_WEBAUTHN_VALIDATOR_ADDRESS);
        } else {
            factory = NexusFactory(NEXUS_FACTORY_ADDRESS);
        }

        // Log the deployed address
        console.log(" - NexusFactory: %s", address(factory));

        vm.stopBroadcast();
    }

    /// @dev Deploy the recovery related stuff
    function _deployRecovery() internal {
        vm.startBroadcast();

        // Deploy the recovery policy if not already deployed
        RecoveryPolicy recoveryPolicy;
        if (RECOVERY_POLICY_ADDRESS.code.length == 0) {
            console.log("Deploying RecoveryPolicy");
            recoveryPolicy = new RecoveryPolicy{salt: 0}();
        } else {
            recoveryPolicy = RecoveryPolicy(RECOVERY_POLICY_ADDRESS);
        }

        // Deploy the recovery action if not already deployed
        MultiWebAuthNRecovery recoveryAction;
        if (RECOVERY_ACTION_ADDRESS.code.length == 0) {
            console.log("Deploying MultiWebAuthNRecovery");
            recoveryAction = new MultiWebAuthNRecovery{salt: 0}(MULTI_WEBAUTHN_VALIDATOR_ADDRESS);
        } else {
            recoveryAction = MultiWebAuthNRecovery(RECOVERY_ACTION_ADDRESS);
        }

        // Log the deployed address
        console.log(" - RecoveryPolicy: %s", address(recoveryPolicy));
        console.log(" - MultiWebAuthNRecovery: %s", address(recoveryAction));

        vm.stopBroadcast();
    }
}
