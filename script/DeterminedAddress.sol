// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
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
    // Monerium
    address moneriumSignMsgAction;
}

/// @dev Binary hashes for deployed contracts
struct BinHashes {
    // Reward system
    bytes32 rewarderHub;
    bytes32 campaignBankFactory;
    // Token
    bytes32 mUSDToken;
    // Kernel
    bytes32 p256Wrapper;
    bytes32 webAuthNValidator;
    bytes32 webAuthNRecoveryAction;
    bytes32 moneriumSignMsgAction;
}

/// @dev Simple contract storing our predetermined addresses
/// @author @KONFeature
contract DeterminedAddress is Script {
    using stdJson for string;

    // JSON files
    string internal addressesFile = "./external/addresses.json";
    string internal kernelFile = "./external/kernelAddresses.json";
    string internal binHashFile = "./external/binHashes.json";

    // Config
    address internal airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;

    /* -------------------------------------------------------------------------- */
    /*                              Address Management                            */
    /* -------------------------------------------------------------------------- */

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
            rewarderHub: _readAddressSafe(json, ".rewarderHub"),
            campaignBankFactory: _readAddressSafe(json, ".campaignBankFactory"),
            mUSDToken: _readAddressSafe(json, ".mUSDToken")
        });
    }

    function _getKernelAddresses() internal returns (KernelAddresses memory) {
        string memory file = _chainFile(kernelFile);

        KernelAddresses memory emptyAddress = KernelAddresses({
            p256Wrapper: address(0),
            webAuthNValidator: address(0),
            webAuthNRecoveryAction: address(0),
            moneriumSignMsgAction: address(0)
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
            p256Wrapper: _readAddressSafe(json, ".p256Wrapper"),
            webAuthNValidator: _readAddressSafe(json, ".webAuthNValidator"),
            webAuthNRecoveryAction: _readAddressSafe(json, ".webAuthNRecoveryAction"),
            moneriumSignMsgAction: _readAddressSafe(json, ".moneriumSignMsgAction")
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
        vm.serializeAddress(jsonKey, "webAuthNRecoveryAction", addresses.webAuthNRecoveryAction);
        string memory finalJson = vm.serializeAddress(jsonKey, "moneriumSignMsgAction", addresses.moneriumSignMsgAction);

        vm.writeJson(finalJson, kernelFile);
        vm.writeJson(finalJson, _chainFile(kernelFile));
    }

    /* -------------------------------------------------------------------------- */
    /*                              BinHash Management                            */
    /* -------------------------------------------------------------------------- */

    function _emptyBinHash() internal pure returns (BinHashes memory) {
        return BinHashes({
            rewarderHub: bytes32(0),
            campaignBankFactory: bytes32(0),
            mUSDToken: bytes32(0),
            p256Wrapper: bytes32(0),
            webAuthNValidator: bytes32(0),
            webAuthNRecoveryAction: bytes32(0),
            moneriumSignMsgAction: bytes32(0)
        });
    }

    /// @dev Save the bin hashes in a json file
    function _saveBinHashes(BinHashes memory hashes) internal {
        string memory jsonKey = "BIN_HASHES_JSON";
        vm.serializeBytes32(jsonKey, "rewarderHub", hashes.rewarderHub);
        vm.serializeBytes32(jsonKey, "campaignBankFactory", hashes.campaignBankFactory);
        vm.serializeBytes32(jsonKey, "mUSDToken", hashes.mUSDToken);
        vm.serializeBytes32(jsonKey, "p256Wrapper", hashes.p256Wrapper);
        vm.serializeBytes32(jsonKey, "webAuthNValidator", hashes.webAuthNValidator);
        vm.serializeBytes32(jsonKey, "webAuthNRecoveryAction", hashes.webAuthNRecoveryAction);
        string memory finalJson = vm.serializeBytes32(jsonKey, "moneriumSignMsgAction", hashes.moneriumSignMsgAction);

        vm.writeJson(finalJson, binHashFile);
        vm.writeJson(finalJson, _chainFile(binHashFile));
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

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

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

    /// @dev Safely read an address from JSON, returning address(0) if key doesn't exist
    function _readAddressSafe(string memory json, string memory key) internal pure returns (address) {
        bytes memory data = vm.parseJson(json, key);
        if (data.length == 0) {
            return address(0);
        }
        return abi.decode(data, (address));
    }
}
