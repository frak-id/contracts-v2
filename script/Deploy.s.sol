// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, BinHashes, DeterminedAddress, KernelAddresses} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CampaignBankFactory} from "src/campaign/CampaignBankFactory.sol";
import {CampaignFactory} from "src/campaign/CampaignFactory.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {InteractionDelegator} from "src/kernel/interaction/InteractionDelegator.sol";
import {InteractionDelegatorAction} from "src/kernel/interaction/InteractionDelegatorAction.sol";
import {InteractionDelegatorValidator} from "src/kernel/interaction/InteractionDelegatorValidator.sol";
import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {MultiWebAuthNRecoveryAction} from "src/kernel/webauthn/MultiWebAuthNRecoveryAction.sol";
import {MultiWebAuthNValidatorV2} from "src/kernel/webauthn/MultiWebAuthNValidator.sol";
import {PurchaseOracle} from "src/oracle/PurchaseOracle.sol";
import {ProductAdministratorRegistry, ProductRoles} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE, ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

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

        addresses = _deployCore(addresses, binHash);
        addresses = _deployTokens(addresses);

        // Log every deployed address
        console.log();
        console.log("Deploying Frak contracts");
        console.log("Addresses:");
        console.log(" - ProductRegistry:                %s", addresses.productRegistry);
        console.log(" - ReferralRegistry:               %s", addresses.referralRegistry);
        console.log(" - ProductAdministratorRegistry:   %s", addresses.productAdministratorRegistry);
        console.log(" - PurchaseOracle:                 %s", addresses.purchaseOracle);
        console.log(" - ProductInteractionManager:      %s", addresses.productInteractionManager);
        console.log(" - FacetFactory:                   %s", addresses.facetFactory);
        console.log(" - CampaignFactory:                %s", addresses.campaignFactory);
        console.log(" - CampaignBankFactory:            %s", addresses.campaignBankFactory);
        console.log(" - MUSDToken:                      %s", addresses.mUSDToken);
        console.log();

        // Save the addresses in a json file
        _saveAddresses(addresses);

        // Then handle kernel deployment
        KernelAddresses memory kAddresses = _deployKernelModules(addresses, binHash);

        console.log();
        console.log("Deploying Kernel contracts");
        console.log("Kernel Addresses:");
        console.log(" - P256VerifierWrapper:            %s", kAddresses.p256Wrapper);
        console.log(" - MultiWebAuthNValidator:         %s", kAddresses.webAuthNValidator);
        console.log(" - MultiWebAuthNRecoveryAction:    %s", kAddresses.webAuthNRecoveryAction);
        console.log(" - InteractionDelegator:           %s", kAddresses.interactionDelegator);
        console.log(" - InteractionDelegatorValidator:  %s", kAddresses.interactionDelegatorValidator);
        console.log(" - InteractionDelegatorAction:     %s", kAddresses.interactionDelegatorAction);

        _saveKernelAddresses(kAddresses);

        // Save the bin hashes
        _saveBinHashes(binHash);
    }

    function _shouldDeploy(address addr) internal view returns (bool) {
        return addr.code.length == 0 || forceDeploy;
    }

    /// @dev Deploy core ecosystem stuff (ProductRegistry, Community token)
    function _deployCore(Addresses memory addresses, BinHashes memory binHash) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the registries
        if (_shouldDeploy(addresses.productRegistry)) {
            console.log(" * Deploying ProductRegistry");
            ProductRegistry productRegistry = new ProductRegistry{
                salt: 0x00000000000000000000000000000000000000001980ec9a58dedfc944a91d58
            }(msg.sender);
            addresses.productRegistry = address(productRegistry);
        }
        bytes32 currHash = _saveBin("ProductRegistry", type(ProductRegistry).creationCode, abi.encode(msg.sender));
        binHash.productRegistry = currHash;

        if (_shouldDeploy(addresses.referralRegistry)) {
            console.log(" * Deploying ReferralRegistry");
            ReferralRegistry referralRegistry = new ReferralRegistry{
                salt: 0x0000000000000000000000000000000000000000f3205585e7112badc5458a5d
            }(msg.sender);
            addresses.referralRegistry = address(referralRegistry);
        }
        currHash = _saveBin("ReferralRegistry", type(ReferralRegistry).creationCode, abi.encode(msg.sender));
        binHash.referralRegistry = currHash;

        if (_shouldDeploy(addresses.productAdministratorRegistry)) {
            console.log(" * Deploying ProductAdministratorRegistry");
            ProductAdministratorRegistry adminRegistry = new ProductAdministratorRegistry{
                salt: 0x0000000000000000000000000000000000000000f671228c921a932dc15fb15f
            }(ProductRegistry(addresses.productRegistry));
            addresses.productAdministratorRegistry = address(adminRegistry);
        }
        currHash = _saveBin(
            "ProductAdministratorRegistry",
            type(ProductAdministratorRegistry).creationCode,
            abi.encode(addresses.productRegistry)
        );
        binHash.productAdministratorRegistry = currHash;

        // Deploy the oracle
        if (_shouldDeploy(addresses.purchaseOracle)) {
            console.log(" * Deploying PurchaseOracle");
            PurchaseOracle purchaseOracle = new PurchaseOracle{
                salt: 0x00000000000000000000000000000000000000004a06bfc117cee6eade059765
            }(ProductAdministratorRegistry(addresses.productAdministratorRegistry));
            addresses.purchaseOracle = address(purchaseOracle);
        }
        currHash = _saveBin(
            "PurchaseOracle", type(PurchaseOracle).creationCode, abi.encode(addresses.productAdministratorRegistry)
        );
        binHash.purchaseOracle = currHash;

        // Deploy the facet factory
        if (_shouldDeploy(addresses.facetFactory)) {
            console.log(" * Deploying InteractionFacetsFactory");
            InteractionFacetsFactory facetFactory = new InteractionFacetsFactory{
                salt: 0x000000000000000000000000000000000000000063e2462e958892e89e060060
            }(
                ReferralRegistry(addresses.referralRegistry),
                ProductRegistry(addresses.productRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorRegistry),
                PurchaseOracle(addresses.purchaseOracle)
            );
            addresses.facetFactory = address(facetFactory);
        }
        currHash = _saveBin(
            "InteractionFacetsFactory",
            type(InteractionFacetsFactory).creationCode,
            abi.encode(
                addresses.referralRegistry,
                addresses.productRegistry,
                addresses.productAdministratorRegistry,
                addresses.purchaseOracle
            )
        );
        binHash.facetFactory = currHash;

        // Deploy the campaign factory
        if (_shouldDeploy(addresses.campaignFactory)) {
            console.log(" * Deploying CampaignFactory");
            CampaignFactory campaignFactory = new CampaignFactory{
                salt: 0x0000000000000000000000000000000000000000dd69b074137eb245cfc20937
            }(
                ReferralRegistry(addresses.referralRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorRegistry)
            );
            addresses.campaignFactory = address(campaignFactory);
        }
        currHash = _saveBin(
            "CampaignFactory",
            type(CampaignFactory).creationCode,
            abi.encode(addresses.referralRegistry, addresses.productAdministratorRegistry)
        );
        binHash.campaignFactory = currHash;

        if (_shouldDeploy(addresses.campaignBankFactory)) {
            console.log(" * Deploying CampaignBankFactory");
            CampaignBankFactory campaignBankFactory = new CampaignBankFactory{
                salt: 0x0000000000000000000000000000000000000000f11894a5f4db45ffdcd21757
            }(ProductAdministratorRegistry(addresses.productAdministratorRegistry));
            addresses.campaignBankFactory = address(campaignBankFactory);
        }
        currHash = _saveBin(
            "CampaignBankFactory",
            type(CampaignBankFactory).creationCode,
            abi.encode(addresses.productAdministratorRegistry)
        );
        binHash.campaignBankFactory = currHash;

        // Deploy the interaction manager if needed
        if (_shouldDeploy(addresses.productInteractionManager)) {
            console.log(" * Deploying ProductInteractionManager under erc1967 proxy");
            // Deploy implem
            address implem = address(
                new ProductInteractionManager{salt: 0x00000000000000000000000000000000000000009574a3ca53239268c072a019}(
                    ProductRegistry(addresses.productRegistry),
                    ReferralRegistry(addresses.referralRegistry),
                    ProductAdministratorRegistry(addresses.productAdministratorRegistry)
                )
            );
            console.log("  ** ProductInteractionManager implementation: %s", implem);
            // Deploy and register proxy
            address proxy = LibClone.deployDeterministicERC1967(
                implem, 0x000000000000000000000000000000000000000066ca83fe94b5b293e05ebc8a
            );
            ProductInteractionManager(proxy).init(
                msg.sender, InteractionFacetsFactory(addresses.facetFactory), CampaignFactory(addresses.campaignFactory)
            );
            addresses.productInteractionManager = proxy;

            // Granr it the role to grant tree access on the referral registry
            ReferralRegistry(addresses.referralRegistry).grantRoles(proxy, REFERRAL_ALLOWANCE_MANAGER_ROLE);
        }
        currHash = _saveBin(
            "ProductInteractionManager",
            type(ProductInteractionManager).creationCode,
            abi.encode(addresses.productRegistry, addresses.referralRegistry, addresses.productAdministratorRegistry)
        );
        binHash.productInteractionManager = currHash;

        vm.stopBroadcast();
        return addresses;
    }

    /// @dev Deploy the test mUSD token
    function _deployTokens(Addresses memory addresses) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the mUSD token if not already deployed
        if (_shouldDeploy(addresses.mUSDToken)) {
            console.log(" * Deploying mUSDToken");
            mUSDToken mUSD = new mUSDToken{salt: 0}(msg.sender);
            mUSD.grantRoles(airdropper, MINTER_ROLE);
            addresses.mUSDToken = address(mUSD);
        }
        vm.stopBroadcast();
        return addresses;
    }

    /// @dev Deploy the kernel modules
    function _deployKernelModules(Addresses memory addresses, BinHashes memory binHash)
        internal
        returns (KernelAddresses memory)
    {
        KernelAddresses memory kAddresses = _getKernelAddresses();

        vm.startBroadcast();

        if (_shouldDeploy(kAddresses.p256Wrapper)) {
            console.log(" * Deploying p256 wrapper");
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
            }(kAddresses.p256Wrapper);
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
            }(kAddresses.webAuthNValidator);
            kAddresses.webAuthNRecoveryAction = address(multiWebAuthNRecovery);
        }
        currHash = _saveBin(
            "MultiWebAuthNRecoveryAction",
            type(MultiWebAuthNRecoveryAction).creationCode,
            abi.encode(kAddresses.webAuthNValidator)
        );
        binHash.webAuthNRecoveryAction = currHash;

        if (_shouldDeploy(kAddresses.interactionDelegator)) {
            console.log(" * Deploying InteractionDelegator");
            InteractionDelegator interactionDelegator = new InteractionDelegator{
                salt: 0x000000000000000000000000000000000000000069f0b5289bd1a427f5ed9370
            }(msg.sender);
            kAddresses.interactionDelegator = address(interactionDelegator);
        }
        currHash = _saveBin("InteractionDelegator", type(InteractionDelegator).creationCode, abi.encode(msg.sender));
        binHash.interactionDelegator = currHash;

        if (_shouldDeploy(kAddresses.interactionDelegatorValidator)) {
            console.log(" * Deploying InteractionDelegatorValidator");
            InteractionDelegatorValidator interactionDelegatorValidator = new InteractionDelegatorValidator{
                salt: 0x0000000000000000000000000000000000000000aa2d3979892b207848398d35
            }(kAddresses.interactionDelegator);
            kAddresses.interactionDelegatorValidator = address(interactionDelegatorValidator);
        }
        currHash = _saveBin(
            "InteractionDelegatorValidator",
            type(InteractionDelegatorValidator).creationCode,
            abi.encode(kAddresses.interactionDelegator)
        );
        binHash.interactionDelegatorValidator = currHash;

        if (_shouldDeploy(kAddresses.interactionDelegatorAction)) {
            console.log(" * Deploying InteractionDelegatorAction");
            InteractionDelegatorAction interactionDelegatorAction = new InteractionDelegatorAction{
                salt: 0x0000000000000000000000000000000000000000f48837f67bb931ec65596e0b
            }(ProductInteractionManager(addresses.productInteractionManager));
            kAddresses.interactionDelegatorAction = address(interactionDelegatorAction);
        }
        currHash = _saveBin(
            "InteractionDelegatorAction",
            type(InteractionDelegatorAction).creationCode,
            abi.encode(addresses.productInteractionManager)
        );
        binHash.interactionDelegatorAction = currHash;

        vm.stopBroadcast();
        return kAddresses;
    }
}
