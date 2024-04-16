// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {WebAuthNValidator} from "src/kernel/v3/WebAuthNValidator.sol";

contract DeployErc7579 is Script {
    address P256_WRAPPER_ADDRESS = 0x169cb43cB17a37E5B022738a2BA6697f0f7b0Bc9;
    address WEBAUTHN_VALIDATOR_ADDRESS = 0x17cD25b8ddB2f8FAbfed47964Bd4a8C2f71f4491;

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
        WebAuthNValidator webAuthNValidator;
        if (WEBAUTHN_VALIDATOR_ADDRESS.code.length == 0) {
            console.log("Deploying WebAuthNValidator");
            webAuthNValidator = new WebAuthNValidator{salt: 0}(address(p256verifierWrapper));
        } else {
            webAuthNValidator = WebAuthNValidator(WEBAUTHN_VALIDATOR_ADDRESS);
        }

        // Log every deployed address
        console.log("Chain: %s", block.chainid);
        console.log(" - P256VerifierWrapper: %s", address(p256verifierWrapper));
        console.log(" - WebAuthNValidator: %s", address(webAuthNValidator));

        vm.stopBroadcast();
    }
}
