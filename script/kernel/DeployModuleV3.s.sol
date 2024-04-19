// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {WebAuthNValidator} from "src/kernel/v3/WebAuthNValidator.sol";
import {MultiWebAuthNValidator} from "src/kernel/v3/MultiWebAuthNValidator.sol";
import {Kernel} from "kernel/Kernel.sol";
import {IEntryPoint} from "kernel/interfaces/IEntryPoint.sol";
import {ValidationId} from "kernel/core/ValidationManager.sol";
import {ValidatorLib} from "kernel/utils/ValidationTypeLib.sol";
import {
    IModule, IValidator, IHook, IExecutor, IFallback, IPolicy, ISigner
} from "kernel/interfaces/IERC7579Modules.sol";

import {LibClone} from "solady/utils/LibClone.sol";

contract DeployModuleV3 is Script {
    address P256_WRAPPER_ADDRESS = 0x169cb43cB17a37E5B022738a2BA6697f0f7b0Bc9;
    address WEBAUTHN_VALIDATOR_ADDRESS = 0xC37aa1E97953064F269FD740f5aC9998E20bA1Ed;
    address MULTI_WEBAUTHN_VALIDATOR_ADDRESS = 0x47430743Cd64A84e2339917bD29B21DbAF4c3C5A;

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
        WebAuthNValidator webAuthNSigner;
        if (WEBAUTHN_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying WebAuthNValidator");
            webAuthNSigner = new WebAuthNValidator{salt: 0}(address(p256verifierWrapper));
        } else {
            webAuthNSigner = WebAuthNValidator(WEBAUTHN_VALIDATOR_ADDRESS);
        }

        // Deploy the multi webauthn validator if not already deployed
        MultiWebAuthNValidator multiWebAuthNSigner;
        if (MULTI_WEBAUTHN_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying MultiWebAuthNValidator");
            multiWebAuthNSigner = new MultiWebAuthNValidator{salt: 0}(address(p256verifierWrapper));
        } else {
            multiWebAuthNSigner = MultiWebAuthNValidator(MULTI_WEBAUTHN_VALIDATOR_ADDRESS);
        }

        // Log every deployed address
        console.log("Chain: %s", block.chainid);
        console.log(" - P256VerifierWrapper: %s", address(p256verifierWrapper));
        console.log(" - WebAuthNValidator: %s", address(webAuthNSigner));
        console.log(" - MultiWebAuthNValidator: %s", address(multiWebAuthNSigner));

        vm.stopBroadcast();
    }
}
