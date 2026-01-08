// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {Addresses, DeterminedAddress, KernelAddresses} from "./DeterminedAddress.sol";

// Kernel
import {MultiWebAuthNRecoveryAction} from "src/kernel/webauthn/MultiWebAuthNRecoveryAction.sol";
import {MultiWebAuthNValidatorV2} from "src/kernel/webauthn/MultiWebAuthNValidator.sol";
import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";

// Reward system
import {RewarderHub} from "src/reward/RewarderHub.sol";
import {CampaignBankFactory} from "src/bank/CampaignBankFactory.sol";

// Token
import {mUSDToken} from "src/tokens/mUSDToken.sol";

// Lib
import {LibClone} from "solady/utils/LibClone.sol";

/// @dev Deploy the frak contracts
/// @author @KONFeature
contract FrakDeploy is DeterminedAddress {
    using LibClone for address;

    // Deployer
    address internal deployer;

    function run() public {
        // Get the deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer: %s", deployer);

        // Start the broadcast
        vm.startBroadcast(deployerPrivateKey);

        // Get the addresses
        Addresses memory addresses = _getAddresses();
        KernelAddresses memory kernelAddresses = _getKernelAddresses();

        // Deploy kernel
        _deployKernel(kernelAddresses);

        // Deploy reward system
        _deployRewardSystem(addresses);

        // Save addresses
        _saveAddresses(addresses);
        _saveKernelAddresses(kernelAddresses);

        // Stop the broadcast
        vm.stopBroadcast();
    }

    /* -------------------------------------------------------------------------- */
    /*                             Kernel Deployment                              */
    /* -------------------------------------------------------------------------- */

    function _deployKernel(KernelAddresses memory addresses) internal {
        // Deploy p256 wrapper if needed
        if (addresses.p256Wrapper == address(0)) {
            addresses.p256Wrapper = address(new P256VerifierWrapper());
            console.log("P256VerifierWrapper deployed at: %s", addresses.p256Wrapper);
        }

        // Deploy webauthn validator if needed
        if (addresses.webAuthNValidator == address(0)) {
            addresses.webAuthNValidator = address(new MultiWebAuthNValidatorV2(addresses.p256Wrapper));
            console.log("MultiWebAuthNValidatorV2 deployed at: %s", addresses.webAuthNValidator);
        }

        // Deploy webauthn recovery action if needed
        if (addresses.webAuthNRecoveryAction == address(0)) {
            addresses.webAuthNRecoveryAction = address(new MultiWebAuthNRecoveryAction(addresses.webAuthNValidator));
            console.log("MultiWebAuthNRecoveryAction deployed at: %s", addresses.webAuthNRecoveryAction);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                          Reward System Deployment                          */
    /* -------------------------------------------------------------------------- */

    function _deployRewardSystem(Addresses memory addresses) internal {
        // Deploy RewarderHub if needed
        if (addresses.rewarderHub == address(0)) {
            // Deploy implementation
            RewarderHub implementation = new RewarderHub();
            console.log("RewarderHub implementation deployed at: %s", address(implementation));

            // Deploy proxy
            address proxy = address(implementation).clone();
            RewarderHub(proxy).init(deployer);
            addresses.rewarderHub = proxy;
            console.log("RewarderHub proxy deployed at: %s", proxy);
        }

        // Deploy CampaignBankFactory if needed
        if (addresses.campaignBankFactory == address(0)) {
            addresses.campaignBankFactory = address(new CampaignBankFactory(addresses.rewarderHub));
            console.log("CampaignBankFactory deployed at: %s", addresses.campaignBankFactory);
        }

        // Deploy mUSD token if needed (testnet only)
        if (addresses.mUSDToken == address(0) && block.chainid != 1 && block.chainid != 42_161) {
            addresses.mUSDToken = address(new mUSDToken(deployer));
            console.log("mUSDToken deployed at: %s", addresses.mUSDToken);
        }
    }
}
