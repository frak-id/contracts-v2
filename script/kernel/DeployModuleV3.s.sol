// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {MultiWebAuthNValidatorV3} from "src/kernel/v3/MultiWebAuthNValidator.sol";

contract DeployModuleV3 is Script {
    address P256_WRAPPER_ADDRESS = 0x97A24c95E317c44c0694200dd0415dD6F556663D;
    //address WEBAUTHN_VALIDATOR_ADDRESS = 0xC11258F3193Bc561ef614E205195cc2129d4B5F6;
    address MULTI_WEBAUTHN_VALIDATOR_ADDRESS = 0xAd2E8dA9f4Cd8A0114B54AECAE03D222AEF0C475;

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
        /*WebAuthNValidator webAuthNSigner;
        if (WEBAUTHN_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying WebAuthNValidator");
            webAuthNSigner = new WebAuthNValidator{salt: 0}(address(p256verifierWrapper));
        } else {
            webAuthNSigner = WebAuthNValidator(WEBAUTHN_VALIDATOR_ADDRESS);
        }*/

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
        //console.log(" - WebAuthNValidator: %s", address(webAuthNSigner));
        console.log(" - MultiWebAuthNValidator: %s", address(multiWebAuthNSigner));

        vm.stopBroadcast();
    }
}
