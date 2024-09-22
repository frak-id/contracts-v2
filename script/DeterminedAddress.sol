// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";

import {stdJson} from "forge-std/StdJson.sol";
import "forge-std/console.sol";
import {LibString} from "solady/utils/LibString.sol";

struct Addresses {
    // Core
    address productRegistry;
    address referralRegistry;
    address productAdministratorRegistry;
    // Oracle
    address purchaseOracle;
    // Interactions
    address facetFactory;
    address productInteractionManager;
    // Campaigns
    address campaignFactory;
    address campaignBankFactory;
    // Token
    address mUSDToken;
}

struct KernelAddresses {
    // WebAuthN
    address p256Wrapper;
    address webAuthNValidator;
    address webAuthNRecoveryAction;
    // InteractionDelegator
    address interactionDelegator;
    address interactionDelegatorValidator;
    address interactionDelegatorAction;
}

struct ProductIds {
    uint256 pNewsPaper;
    uint256 pEthccDemo;
}

struct DeploymentBlocks {
    uint256 arbSepolia;
}

/// @dev simple contract storing our predetermined address
contract DeterminedAddress is Script {
    using stdJson for string;

    // JSON files
    string internal addressesFile = "./external/addresses.json";
    string internal kernelFile = "./external/kernelAddresses.json";

    // Config
    address internal airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;
    address internal productOwner = 0x7caF754C934710D7C73bc453654552BEcA38223F;

    // news paper product
    uint256 internal pNewsPaper =
        20_376_791_661_718_660_580_662_410_765_070_640_284_736_320_707_848_823_176_694_931_891_585_259_913_409;
    uint256 internal pEthccWallet =
        33_953_649_417_576_654_953_995_537_313_820_306_697_747_390_492_794_311_279_756_157_547_821_320_957_282;

    function _getAddresses() internal returns (Addresses memory) {
        string memory file = _nexusChainFile();

        Addresses memory emptyAddress = Addresses({
            productRegistry: address(0),
            referralRegistry: address(0),
            productAdministratorRegistry: address(0),
            purchaseOracle: address(0),
            productInteractionManager: address(0),
            facetFactory: address(0),
            campaignFactory: address(0),
            campaignBankFactory: address(0),
            mUSDToken: address(0)
        });

        // Check if the file exist
        if (!vm.exists(file)) {
            file = addressesFile;
        }
        if (!vm.exists(file)) {
            console.log("File does not exist: %s", file);
            return emptyAddress;
        }

        // Get the addresses for the current chain
        string memory json = vm.readFile(file);
        if (bytes(json).length == 0) {
            console.log("Per chain file is empty: %s", file);
            json = vm.readFile(addressesFile);
        }
        if (bytes(json).length == 0) {
            console.log("Global file is empty: %s", addressesFile);
            return emptyAddress;
        }

        return Addresses({
            productRegistry: json.readAddress(".productRegistry"),
            referralRegistry: json.readAddress(".referralRegistry"),
            productAdministratorRegistry: json.readAddress(".productAdministratorRegistry"),
            purchaseOracle: json.readAddress(".purchaseOracle"),
            productInteractionManager: json.readAddress(".productInteractionManager"),
            facetFactory: json.readAddress(".facetFactory"),
            campaignFactory: json.readAddress(".campaignFactory"),
            campaignBankFactory: json.readAddress(".campaignBankFactory"),
            mUSDToken: json.readAddress(".mUSDToken")
        });
    }

    function _getKernelAddresses() internal returns (KernelAddresses memory) {
        string memory file = _kernelChainFile();

        KernelAddresses memory emptyAddress = KernelAddresses({
            p256Wrapper: address(0),
            webAuthNValidator: address(0),
            webAuthNRecoveryAction: address(0),
            interactionDelegator: address(0),
            interactionDelegatorValidator: address(0),
            interactionDelegatorAction: address(0)
        });

        // Check if the file exist
        if (!vm.exists(file)) {
            file = kernelFile;
        }
        if (!vm.exists(file)) {
            console.log("File does not exist: %s", file);
            return emptyAddress;
        }

        // Read the json
        string memory json = vm.readFile(file);
        if (bytes(json).length == 0) {
            console.log("Per chain file is empty: %s", file);
            json = vm.readFile(kernelFile);
        }
        if (bytes(json).length == 0) {
            console.log("Global file is empty: %s", kernelFile);
            return emptyAddress;
        }

        return KernelAddresses({
            p256Wrapper: json.readAddress(".p256Wrapper"),
            webAuthNValidator: json.readAddress(".webAuthNValidator"),
            webAuthNRecoveryAction: json.readAddress(".webAuthNRecoveryAction"),
            interactionDelegator: json.readAddress(".interactionDelegator"),
            interactionDelegatorValidator: json.readAddress(".interactionDelegatorValidator"),
            interactionDelegatorAction: json.readAddress(".interactionDelegatorAction")
        });
    }

    function _getProductIds() internal view returns (ProductIds memory) {
        return ProductIds({pNewsPaper: pNewsPaper, pEthccDemo: pEthccWallet});
    }

    function _getProductIdsArr() internal view returns (uint256[] memory arr) {
        arr = new uint256[](2);
        arr[0] = pNewsPaper;
        arr[1] = pEthccWallet;
    }

    function _getDeploymentBlocks() internal pure returns (DeploymentBlocks memory) {
        return DeploymentBlocks({arbSepolia: 66_229_858});
    }

    /// @dev Save the addresses in a json file
    function _saveAddresses(Addresses memory addresses) internal {
        // Save the addresses in a json file
        string memory jsonKey = "ADDRESSES_JSON";
        vm.serializeAddress(jsonKey, "productRegistry", addresses.productRegistry);
        vm.serializeAddress(jsonKey, "referralRegistry", addresses.referralRegistry);
        vm.serializeAddress(jsonKey, "productAdministratorRegistry", addresses.productAdministratorRegistry);
        vm.serializeAddress(jsonKey, "purchaseOracle", addresses.purchaseOracle);
        vm.serializeAddress(jsonKey, "facetFactory", addresses.facetFactory);
        vm.serializeAddress(jsonKey, "productInteractionManager", addresses.productInteractionManager);
        vm.serializeAddress(jsonKey, "campaignFactory", addresses.campaignFactory);
        vm.serializeAddress(jsonKey, "campaignBankFactory", addresses.campaignBankFactory);
        string memory finalJson = vm.serializeAddress(jsonKey, "mUSDToken", addresses.mUSDToken);

        // Write it to the file
        vm.writeJson(finalJson, addressesFile);
        vm.writeJson(finalJson, _nexusChainFile());
    }

    /// @dev Save the addresses in a json file
    function _saveKernelAddresses(KernelAddresses memory addresses) internal {
        // Save the addresses in a json file
        string memory jsonKey = "KERNEL_ADDRESSES_JSON";
        vm.serializeAddress(jsonKey, "p256Wrapper", addresses.p256Wrapper);
        vm.serializeAddress(jsonKey, "webAuthNValidator", addresses.webAuthNValidator);
        vm.serializeAddress(jsonKey, "webAuthNRecoveryAction", addresses.webAuthNRecoveryAction);
        vm.serializeAddress(jsonKey, "interactionDelegator", addresses.interactionDelegator);
        vm.serializeAddress(jsonKey, "interactionDelegatorValidator", addresses.interactionDelegatorValidator);
        string memory finalJson =
            vm.serializeAddress(jsonKey, "interactionDelegatorAction", addresses.interactionDelegatorAction);

        vm.writeJson(finalJson, kernelFile);
        vm.writeJson(finalJson, _kernelChainFile());
    }

    function _nexusChainFile() internal view returns (string memory) {
        return string.concat("external/addresses.", LibString.toString(block.chainid), ".json");
    }

    function _kernelChainFile() internal view returns (string memory) {
        return string.concat("external/kernelAddresses.", LibString.toString(block.chainid), ".json");
    }
}
