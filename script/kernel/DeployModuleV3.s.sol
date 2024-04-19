// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {WebAuthNValidator} from "src/kernel/v3/WebAuthNValidator.sol";
import {Kernel} from "kernel-v3/Kernel.sol";
import {IEntryPoint} from "kernel-v3/interfaces/IEntryPoint.sol";
import {ValidationId} from "kernel-v3/core/ValidationManager.sol";
import {ValidatorLib} from "kernel-v3/utils/ValidationTypeLib.sol";
import {
    IModule,
    IValidator,
    IHook,
    IExecutor,
    IFallback,
    IPolicy,
    ISigner
} from "kernel-v3/interfaces/IERC7579Modules.sol";

import {LibClone} from "solady/utils/LibClone.sol";

contract DeployModuleV3 is Script {
    address P256_WRAPPER_ADDRESS = 0x169cb43cB17a37E5B022738a2BA6697f0f7b0Bc9;
    address WEBAUTHN_VALIDATOR_ADDRESS = 0x39ea8C5Ec02E670c750076F468234e7194A7EBb7;

    function run() public {
        deploy();
    }

    function deploy() internal {
        vm.startBroadcast();

        // Deploy the paywall token if not already deployed
        P256VerifierWrapper p256verifierWrapper;
        if (P256_WRAPPER_ADDRESS.code.length == 0) {
            console.log("Deploying p256 wrapper");
            p256verifierWrapper = new P256VerifierWrapper{salt: 0}();
        } else {
            p256verifierWrapper = P256VerifierWrapper(P256_WRAPPER_ADDRESS);
        }

        // Deploy the paywall token if not already deployed
        WebAuthNValidator webAuthNSigner;
        if (WEBAUTHN_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying WebAuthNValidator");
            webAuthNSigner = new WebAuthNValidator{salt: 0}(address(p256verifierWrapper));
        } else {
            webAuthNSigner = WebAuthNValidator(WEBAUTHN_VALIDATOR_ADDRESS);
        }

        // Log every deployed address
        console.log("Chain: %s", block.chainid);
        console.log(" - P256VerifierWrapper: %s", address(p256verifierWrapper));
        console.log(" - WebAuthNValidator: %s", address(webAuthNSigner));

        // Test init
        webAuthNSigner.onInstall(
            hex"0bc9355d14a5dc227ca3b1e6ded768f74ea5cde6255bd324ee0a2f401c6c5714b71fd5bbfd98566c4e41d0249b4c797ee0ba06c89caf12d06c3d302440c2a80f036d62743d3e7ea7df7c40cc0767412c20a4cfb0bcca7ff5f671c860ece981ae"
        );

        // Test kernel init
        address kernelLogic = 0x94F097E1ebEB4ecA3AAE54cabb08905B239A7D27;
        bytes memory validatorData =
            hex"0bc9355d14a5dc227ca3b1e6ded768f74ea5cde6255bd324ee0a2f401c6c5714b71fd5bbfd98566c4e41d0249b4c797ee0ba06c89caf12d06c3d302440c2a80f036d62743d3e7ea7df7c40cc0767412c20a4cfb0bcca7ff5f671c860ece981ae";
        bytes memory hookData = hex"";
        ValidationId validatorId = ValidatorLib.validatorToIdentifier(webAuthNSigner);

        // Kernel kernel = new Kernel{salt: keccak256(abi.encodePacked("Random shit")) }(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032));
        //kernel.initialize(validatorId, IHook(address(0)), validatorData, hookData);

        (bool alreadyDeployed, address account) =
            LibClone.createDeterministicERC1967(0, kernelLogic, keccak256(abi.encodePacked("Random shit")));
        if (!alreadyDeployed) {
            Kernel(payable(account)).initialize(validatorId, IHook(address(0)), validatorData, hookData);
        }

        // Try to get the sender address for the given data
        IEntryPoint entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
        entryPoint.getSenderAddress(
            hex"d703aaE79538628d27099B8c4f621bE4CCd142d5c5265d5d0000000000000000000000006723b44abeec4e71ebe3232bd5b455805badd22f00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012412af322c0039ea8C5Ec02E670c750076F468234e7194A7EBb7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000600bc9355d14a5dc227ca3b1e6ded768f74ea5cde6255bd324ee0a2f401c6c5714b71fd5bbfd98566c4e41d0249b4c797ee0ba06c89caf12d06c3d302440c2a80f036d62743d3e7ea7df7c40cc0767412c20a4cfb0bcca7ff5f671c860ece981ae000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        );

        vm.stopBroadcast();
    }
}
