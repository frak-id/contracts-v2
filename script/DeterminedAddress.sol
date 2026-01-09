// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Script.sol";

import {stdJson} from "forge-std/StdJson.sol";
import "forge-std/console.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @dev Addresses for the Frak ecosystem
struct Addresses {
    // Reward system
    address rewarderHub;
    address campaignBankFactory;
    // Token
    address mUSDToken;
}

/// @dev Addresses for Kernel plugins
struct KernelAddresses {
    // WebAuthN
    address p256Wrapper;
    address webAuthNValidator;
    address webAuthNRecoveryAction;
}

/// @dev simple contract storing our predetermined address
contract DeterminedAddress is Script {
    using stdJson for string;

    // JSON files
    string internal addressesFile = "./external/addresses.json";
    string internal kernelFile = "./external/kernelAddresses.json";

    // Config
    address internal airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;

    function _getAddresses() internal returns (Addresses memory) {
        string memory file = _chainFile(addressesFile);

        Addresses memory emptyAddress =
            Addresses({rewarderHub: address(0), campaignBankFactory: address(0), mUSDToken: address(0)});

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
            rewarderHub: json.readAddress(".rewarderHub"),
            campaignBankFactory: json.readAddress(".campaignBankFactory"),
            mUSDToken: json.readAddress(".mUSDToken")
        });
    }

    function _getKernelAddresses() internal returns (KernelAddresses memory) {
        string memory file = _chainFile(kernelFile);

        KernelAddresses memory emptyAddress = KernelAddresses({
            p256Wrapper: address(0), webAuthNValidator: address(0), webAuthNRecoveryAction: address(0)
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
            webAuthNRecoveryAction: json.readAddress(".webAuthNRecoveryAction")
        });
    }

    /// @dev Save the addresses in a json file
    function _saveAddresses(Addresses memory addresses) internal {
        // Save the addresses in a json file
        string memory jsonKey = "ADDRESSES_JSON";
        vm.serializeAddress(jsonKey, "rewarderHub", addresses.rewarderHub);
        vm.serializeAddress(jsonKey, "campaignBankFactory", addresses.campaignBankFactory);
        string memory finalJson = vm.serializeAddress(jsonKey, "mUSDToken", addresses.mUSDToken);

        // Write it to the file
        vm.writeJson(finalJson, addressesFile);
        vm.writeJson(finalJson, _chainFile(addressesFile));
    }

    /// @dev Save the kernel addresses in a json file
    function _saveKernelAddresses(KernelAddresses memory addresses) internal {
        // Save the addresses in a json file
        string memory jsonKey = "KERNEL_ADDRESSES_JSON";
        vm.serializeAddress(jsonKey, "p256Wrapper", addresses.p256Wrapper);
        vm.serializeAddress(jsonKey, "webAuthNValidator", addresses.webAuthNValidator);
        string memory finalJson =
            vm.serializeAddress(jsonKey, "webAuthNRecoveryAction", addresses.webAuthNRecoveryAction);

        vm.writeJson(finalJson, kernelFile);
        vm.writeJson(finalJson, _chainFile(kernelFile));
    }

    /// @dev Save the binary of a contract to a file
    function _saveBin(string memory name, bytes memory _creationCode) internal returns (bytes32 hash) {
        return _saveBin(name, _creationCode, "");
    }

    /// @dev Save the binary of a contract to a file and return the binary hash
    function _saveBin(string memory name, bytes memory _creationCode, bytes memory _initParams)
        internal
        returns (bytes32 hash)
    {
        string memory file = string.concat("bin/", LibString.toString(block.chainid), "/", name, ".bin");
        bytes memory bin = abi.encodePacked(_creationCode, _initParams);
        vm.writeFile(file, vm.toString(bin));

        hash = keccak256(bin);
    }

    function _chainFile(string memory baseFile) internal view returns (string memory) {
        // Remove .json extension and add chain id
        bytes memory baseBytes = bytes(baseFile);
        uint256 len = baseBytes.length;

        // Find the last dot
        uint256 dotIndex = len;
        for (uint256 i = len; i > 0; i--) {
            if (baseBytes[i - 1] == ".") {
                dotIndex = i - 1;
                break;
            }
        }

        // Build new filename: base.chainId.json
        string memory baseName = string(abi.encodePacked(baseFile));
        if (dotIndex < len) {
            bytes memory nameBytes = new bytes(dotIndex);
            for (uint256 i = 0; i < dotIndex; i++) {
                nameBytes[i] = baseBytes[i];
            }
            baseName = string(nameBytes);
        }

        return string.concat(baseName, ".", LibString.toString(block.chainid), ".json");
    }
}
