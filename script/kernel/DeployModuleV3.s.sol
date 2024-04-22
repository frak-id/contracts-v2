// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {MultiWebAuthNValidatorV3} from "src/kernel/v3/MultiWebAuthNValidator.sol";
import {WebAuthNValidatorV3} from "src/kernel/v3/WebAuthNValidator.sol";

contract DeployModuleV3 is Script {
    address P256_WRAPPER_ADDRESS = 0x97A24c95E317c44c0694200dd0415dD6F556663D;
    address WEBAUTHN_VALIDATOR_ADDRESS = 0x7caF754C934710D7C73bc453654552BEcA38223F;
    address MULTI_WEBAUTHN_VALIDATOR_ADDRESS = 0x7caF754C934710D7C73bc453654552BEcA38223F;

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
        console.log("Chain: %s", block.chainid);
        console.log(" - P256VerifierWrapper: %s", address(p256verifierWrapper));
        console.log(" - WebAuthNValidatorV3: %s", address(webAuthNSigner));
        console.log(" - MultiWebAuthNValidatorV3: %s", address(multiWebAuthNSigner));

        vm.stopBroadcast();
    }
}
