// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress, KernelAddresses} from "./DeterminedAddress.sol";
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

        addresses = _deployCore(addresses);
        addresses = _deployTokens(addresses);

        // Log every deployed address
        console.log();
        console.log("Deployed all Frak contracts");
        console.log("Addresses:");
        console.log(" - ProductRegistry: %s", addresses.productRegistry);
        console.log(" - ReferralRegistry: %s", addresses.referralRegistry);
        console.log(" - ProductAdministratorRegistry: %s", addresses.productAdministratorRegistry);
        console.log(" - PurchaseOracle: %s", addresses.purchaseOracle);
        console.log(" - ProductInteractionManager: %s", addresses.productInteractionManager);
        console.log(" - FacetFactory: %s", addresses.facetFactory);
        console.log(" - CampaignFactory: %s", addresses.campaignFactory);
        console.log(" - CampaignBankFactory: %s", addresses.campaignBankFactory);
        console.log(" - MUSDToken: %s", addresses.mUSDToken);
        console.log();

        // Save the addresses in a json file
        _saveAddresses(addresses);

        // Then handle kernel deployment
        KernelAddresses memory kAddresses = _deployKernelModules(addresses);

        console.log();
        console.log("Deployed all Kernel contracts");
        console.log("Kernel Addresses:");
        console.log(" - P256VerifierWrapper: %s", kAddresses.p256Wrapper);
        console.log(" - MultiWebAuthNValidator: %s", kAddresses.webAuthNValidator);
        console.log(" - MultiWebAuthNRecoveryAction: %s", kAddresses.webAuthNRecoveryAction);
        console.log(" - InteractionDelegator: %s", kAddresses.interactionDelegator);
        console.log(" - InteractionDelegatorValidator: %s", kAddresses.interactionDelegatorValidator);
        console.log(" - InteractionDelegatorAction: %s", kAddresses.interactionDelegatorAction);

        _saveKernelAddresses(kAddresses);
    }

    function _shouldDeploy(address addr) internal view returns (bool) {
        return addr.code.length == 0 || forceDeploy;
    }

    /// @dev Deploy core ecosystem stuff (ProductRegistry, Community token)
    function _deployCore(Addresses memory addresses) internal returns (Addresses memory) {
        vm.startBroadcast();

        // Deploy the registries
        if (_shouldDeploy(addresses.productRegistry)) {
            console.log(" * Deploying ProductRegistry");
            ProductRegistry productRegistry = new ProductRegistry{
                salt: 0xae4e57b886541829ba70efc84340653c41e2908c59ed75dc94a425451637437d
            }(msg.sender);
            addresses.productRegistry = address(productRegistry);
        }
        if (_shouldDeploy(addresses.referralRegistry)) {
            console.log(" * Deploying ReferralRegistry");
            ReferralRegistry referralRegistry = new ReferralRegistry{
                salt: 0xae4e57b886541829ba70efc84340653c41e2908c27ea1090cbdde3109a73c0ca
            }(msg.sender);
            addresses.referralRegistry = address(referralRegistry);
        }
        if (_shouldDeploy(addresses.productAdministratorRegistry)) {
            console.log(" * Deploying ProductAdministratorRegistry");
            ProductAdministratorRegistry adminRegistry = new ProductAdministratorRegistry{
                salt: 0xae4e57b886541829ba70efc84340653c41e2908c0fb70d6ed9a3af080e01c6da
            }(ProductRegistry(addresses.productRegistry));
            addresses.productAdministratorRegistry = address(adminRegistry);
        }

        // Deploy the oracle
        if (_shouldDeploy(addresses.purchaseOracle)) {
            console.log(" * Deploying PurchaseOracle");
            PurchaseOracle purchaseOracle =
                new PurchaseOracle{salt: 0}(ProductAdministratorRegistry(addresses.productAdministratorRegistry));
            addresses.purchaseOracle = address(purchaseOracle);
        }

        // Deploy the facet factory
        if (_shouldDeploy(addresses.facetFactory)) {
            console.log(" * Deploying InteractionFacetsFactory");
            InteractionFacetsFactory facetFactory = new InteractionFacetsFactory{salt: 0}(
                ReferralRegistry(addresses.referralRegistry),
                ProductRegistry(addresses.productRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorRegistry),
                PurchaseOracle(addresses.purchaseOracle)
            );
            addresses.facetFactory = address(facetFactory);
        }

        // Deploy the campaign factory
        if (_shouldDeploy(addresses.campaignFactory)) {
            console.log(" * Deploying CampaignFactory");
            CampaignFactory campaignFactory = new CampaignFactory{salt: 0}(
                ReferralRegistry(addresses.referralRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorRegistry)
            );
            addresses.campaignFactory = address(campaignFactory);
        }
        if (_shouldDeploy(addresses.campaignBankFactory)) {
            console.log(" * Deploying CampaignBankFactory");
            CampaignBankFactory campaignBankFactory =
                new CampaignBankFactory{salt: 0}(ProductAdministratorRegistry(addresses.productAdministratorRegistry));
            addresses.campaignBankFactory = address(campaignBankFactory);
        }

        // Deploy the interaction manager if needed
        if (_shouldDeploy(addresses.productInteractionManager)) {
            console.log(" * Deploying ProductInteractionManager under erc1967 proxy");
            // Deploy implem
            address implem = address(
                new ProductInteractionManager{salt: 0xae4e57b886541829ba70efc84340653c41e2908c01f8a8bf450799131401a2fd}(
                    ProductRegistry(addresses.productRegistry),
                    ReferralRegistry(addresses.referralRegistry),
                    ProductAdministratorRegistry(addresses.productAdministratorRegistry)
                )
            );
            console.log("  ** ProductInteractionManager implementation: %s", implem);
            // Deploy and register proxy
            address proxy = LibClone.deployDeterministicERC1967(
                implem, 0xae4e57b886541829ba70efc84340653c41e2908c74c911196efa85290dc9cb2b
            );
            ProductInteractionManager(proxy).init(
                msg.sender, InteractionFacetsFactory(addresses.facetFactory), CampaignFactory(addresses.campaignFactory)
            );
            addresses.productInteractionManager = proxy;

            // Granr it the role to grant tree access on the referral registry
            ReferralRegistry(addresses.referralRegistry).grantRoles(proxy, REFERRAL_ALLOWANCE_MANAGER_ROLE);
        }

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
    function _deployKernelModules(Addresses memory addresses) internal returns (KernelAddresses memory) {
        KernelAddresses memory kAddresses = _getKernelAddresses();

        vm.startBroadcast();

        if (_shouldDeploy(kAddresses.p256Wrapper)) {
            console.log(" * Deploying p256 wrapper");
            P256VerifierWrapper p256verifierWrapper = new P256VerifierWrapper{salt: 0}();
            kAddresses.p256Wrapper = address(p256verifierWrapper);
        }

        if (_shouldDeploy(kAddresses.webAuthNValidator)) {
            console.log(" * Deploying MultiWebAuthNValidator");
            MultiWebAuthNValidatorV2 multiWebAuthNSigner = new MultiWebAuthNValidatorV2{salt: 0}(kAddresses.p256Wrapper);
            kAddresses.webAuthNValidator = address(multiWebAuthNSigner);
        }

        if (_shouldDeploy(kAddresses.webAuthNRecoveryAction)) {
            console.log(" * Deploying MultiWebAuthNRecoveryAction");
            MultiWebAuthNRecoveryAction multiWebAuthNRecovery =
                new MultiWebAuthNRecoveryAction{salt: 0}(kAddresses.webAuthNValidator);
            kAddresses.webAuthNRecoveryAction = address(multiWebAuthNRecovery);
        }

        if (_shouldDeploy(kAddresses.interactionDelegator)) {
            console.log(" * Deploying InteractionDelegator");
            InteractionDelegator interactionDelegator = new InteractionDelegator{salt: 0}(msg.sender);
            kAddresses.interactionDelegator = address(interactionDelegator);
        }

        if (_shouldDeploy(kAddresses.interactionDelegatorValidator)) {
            console.log(" * Deploying InteractionDelegatorValidator");
            InteractionDelegatorValidator interactionDelegatorValidator =
                new InteractionDelegatorValidator{salt: 0}(kAddresses.interactionDelegator);
            kAddresses.interactionDelegatorValidator = address(interactionDelegatorValidator);
        }

        if (_shouldDeploy(kAddresses.interactionDelegatorAction)) {
            console.log(" * Deploying InteractionDelegatorAction");
            InteractionDelegatorAction interactionDelegatorAction =
                new InteractionDelegatorAction{salt: 0}(ProductInteractionManager(addresses.productInteractionManager));
            kAddresses.interactionDelegatorAction = address(interactionDelegatorAction);
        }

        vm.stopBroadcast();
        return kAddresses;
    }
}
