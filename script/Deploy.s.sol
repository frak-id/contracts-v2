// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, BinHashes, DeterminedAddress, KernelAddresses} from "./DeterminedAddress.sol";
import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {LibClone} from "solady/utils/LibClone.sol";

// Reward system
import {CampaignBankFactory} from "src/bank/CampaignBankFactory.sol";
import {RewarderHub} from "src/reward/RewarderHub.sol";

// Token
import {MINTER_ROLE, mUSDToken} from "src/tokens/mUSDToken.sol";

// Kernel
import {MoneriumSignMsgAction} from "src/kernel/monerium/MoneriumSignMsgAction.sol";
import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {MultiWebAuthNRecoveryAction} from "src/kernel/webauthn/MultiWebAuthNRecoveryAction.sol";
import {MultiWebAuthNValidatorV2} from "src/kernel/webauthn/MultiWebAuthNValidator.sol";

/// @dev Deploy the frak contracts
/// @author @KONFeature
contract Deploy is Script, DeterminedAddress {
    using stdJson for string;

    bool internal forceDeploy = vm.envOr("FORCE_DEPLOY", false);

    function run() public {
        console.log("Starting deployment");
        console.log(" - Chain: %s", block.chainid);
        console.log(" - Sender: %s", msg.sender);
        console.log(" - Force deploy: %s", forceDeploy);
        console.log();

        // The pre computed contract addresses
        Addresses memory addresses = _getAddresses();

        // The empty initial bin hashes
        BinHashes memory binHash = _emptyBinHash();

        // Deploy reward system
        addresses = _deployRewardSystem(addresses, binHash);

        // Deploy tokens
        addresses = _deployTokens(addresses, binHash);

        // Log every deployed address
        console.log();
        console.log("Deploying Frak contracts");
        console.log("Addresses:");
        console.log(" - RewarderHub:          %s", addresses.rewarderHub);
        console.log(" - CampaignBankFactory:  %s", addresses.campaignBankFactory);
        console.log(" - mUSDToken:            %s", addresses.mUSDToken);
        console.log();

        // Save the addresses in a json file
        _saveAddresses(addresses);

        // Then handle kernel deployment
        KernelAddresses memory kAddresses = _deployKernelModules(binHash);

        console.log();
        console.log("Deploying Kernel contracts");
        console.log("Kernel Addresses:");
        console.log(" - P256VerifierWrapper:         %s", kAddresses.p256Wrapper);
        console.log(" - MultiWebAuthNValidator:      %s", kAddresses.webAuthNValidator);
        console.log(" - MultiWebAuthNRecoveryAction: %s", kAddresses.webAuthNRecoveryAction);
        console.log(" - MoneriumSignMsgAction:       %s", kAddresses.moneriumSignMsgAction);

        _saveKernelAddresses(kAddresses);

        // Save the bin hashes
        _saveBinHashes(binHash);
    }

    function _shouldDeploy(address addr) internal view returns (bool) {
        return addr.code.length == 0 || forceDeploy;
    }

    /* -------------------------------------------------------------------------- */
    /*                          Reward System Deployment                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy the reward system contracts
    function _deployRewardSystem(Addresses memory addresses, BinHashes memory binHash)
        internal
        returns (Addresses memory)
    {
        vm.startBroadcast();

        // Deploy RewarderHub if needed
        if (_shouldDeploy(addresses.rewarderHub)) {
            console.log(" * Deploying RewarderHub under ERC1967 proxy");

            // Deploy implementation
            address implem =
                address(new RewarderHub{salt: 0x0000000000000000000000000000000000000000000000000000000000000000}());
            console.log("  ** RewarderHub implementation: %s", implem);

            // Deploy ERC1967 proxy (required for UUPS upgradeability)
            address proxy = LibClone.deployDeterministicERC1967(
                implem, 0x0000000000000000000000000000000000000000000000000000000000000001
            );
            RewarderHub(proxy).init(msg.sender);
            addresses.rewarderHub = proxy;
        }
        bytes32 currHash = _saveBin("RewarderHub", type(RewarderHub).creationCode);
        binHash.rewarderHub = currHash;

        // Deploy CampaignBankFactory if needed
        if (_shouldDeploy(addresses.campaignBankFactory)) {
            console.log(" * Deploying CampaignBankFactory");
            CampaignBankFactory campaignBankFactory = new CampaignBankFactory{
                salt: 0x0000000000000000000000000000000000000000000000000000000000000000
            }(
                addresses.rewarderHub
            );
            addresses.campaignBankFactory = address(campaignBankFactory);
        }
        currHash =
            _saveBin("CampaignBankFactory", type(CampaignBankFactory).creationCode, abi.encode(addresses.rewarderHub));
        binHash.campaignBankFactory = currHash;

        vm.stopBroadcast();
        return addresses;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Token Deployment                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy the test mUSD token
    function _deployTokens(Addresses memory addresses, BinHashes memory binHash) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the mUSD token if not already deployed
        if (_shouldDeploy(addresses.mUSDToken)) {
            console.log(" * Deploying mUSDToken");
            mUSDToken mUSD = new mUSDToken{salt: 0}(msg.sender);
            mUSD.grantRoles(airdropper, MINTER_ROLE);
            addresses.mUSDToken = address(mUSD);
        }
        bytes32 currHash = _saveBin("mUSDToken", type(mUSDToken).creationCode, abi.encode(msg.sender));
        binHash.mUSDToken = currHash;

        vm.stopBroadcast();
        return addresses;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Kernel Deployment                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy the kernel modules
    function _deployKernelModules(BinHashes memory binHash) internal returns (KernelAddresses memory) {
        KernelAddresses memory kAddresses = _getKernelAddresses();

        vm.startBroadcast();

        if (_shouldDeploy(kAddresses.p256Wrapper)) {
            console.log(" * Deploying P256VerifierWrapper");
            P256VerifierWrapper p256verifierWrapper =
                new P256VerifierWrapper{salt: 0x0000000000000000000000000000000000000000ca906bf5e0928035f7b75ffa}();
            kAddresses.p256Wrapper = address(p256verifierWrapper);
        }
        bytes32 currHash = _saveBin("P256VerifierWrapper", type(P256VerifierWrapper).creationCode);
        binHash.p256Wrapper = currHash;

        if (_shouldDeploy(kAddresses.webAuthNValidator)) {
            console.log(" * Deploying MultiWebAuthNValidator");
            MultiWebAuthNValidatorV2 multiWebAuthNSigner = new MultiWebAuthNValidatorV2{
                salt: 0x0000000000000000000000000000000000000000442dd0f774d53742ba542281
            }(
                kAddresses.p256Wrapper
            );
            kAddresses.webAuthNValidator = address(multiWebAuthNSigner);
        }
        currHash = _saveBin(
            "MultiWebAuthNValidatorV2", type(MultiWebAuthNValidatorV2).creationCode, abi.encode(kAddresses.p256Wrapper)
        );
        binHash.webAuthNValidator = currHash;

        if (_shouldDeploy(kAddresses.webAuthNRecoveryAction)) {
            console.log(" * Deploying MultiWebAuthNRecoveryAction");
            MultiWebAuthNRecoveryAction multiWebAuthNRecovery = new MultiWebAuthNRecoveryAction{
                salt: 0x0000000000000000000000000000000000000000c66200b9a9a8bbcfff2a3d87
            }(
                kAddresses.webAuthNValidator
            );
            kAddresses.webAuthNRecoveryAction = address(multiWebAuthNRecovery);
        }
        currHash = _saveBin(
            "MultiWebAuthNRecoveryAction",
            type(MultiWebAuthNRecoveryAction).creationCode,
            abi.encode(kAddresses.webAuthNValidator)
        );
        binHash.webAuthNRecoveryAction = currHash;

        if (_shouldDeploy(kAddresses.moneriumSignMsgAction)) {
            console.log(" * Deploying MoneriumSignMsgAction");
            MoneriumSignMsgAction moneriumSignMsgAction = new MoneriumSignMsgAction{salt: 0}();
            kAddresses.moneriumSignMsgAction = address(moneriumSignMsgAction);
        }
        currHash = _saveBin("MoneriumSignMsgAction", type(MoneriumSignMsgAction).creationCode);
        binHash.moneriumSignMsgAction = currHash;

        vm.stopBroadcast();
        return kAddresses;
    }
}
