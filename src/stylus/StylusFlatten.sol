// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

interface IContentConsumptionContract {
    function initialize(address owner) external;

    function getNonceForPlatform(address user, bytes32 platform_id) external view returns (uint256);

    function pushCcu(
        address user,
        bytes32 platform_id,
        uint256 added_consumption,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function registerPlatform(
        string calldata name,
        string calldata origin,
        address owner,
        bytes32 content_type,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bytes32);

    function domainSeparator() external view returns (bytes32);

    function updatePlatformMetadata(bytes32 platform_id, string calldata name, address owner) external;

    function getPlatformMetadata(bytes32 platform_id) external view returns (address, bytes32);

    function getPlatformName(bytes32 platform_id) external view returns (string memory);

    function getPlatforOrigin(bytes32 platform_id) external view returns (string memory);
}

contract StylusFlattened is IContentConsumptionContract {
    function initialize(address owner) external override {}

    function getNonceForPlatform(address user, bytes32 platform_id) external view override returns (uint256) {
        return 0;
    }

    function pushCcu(
        address user,
        bytes32 platform_id,
        uint256 added_consumption,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {}

    function registerPlatform(
        string calldata name,
        string calldata origin,
        address owner,
        bytes32 content_type,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (bytes32) {
        return 0;
    }

    function domainSeparator() external view override returns (bytes32) {
        return 0;
    }

    function updatePlatformMetadata(bytes32 platform_id, string calldata name, address owner) external override {}

    function getPlatformMetadata(bytes32 platform_id) external view override returns (address, bytes32) {
        return (address(0), 0);
    }

    function getPlatformName(bytes32 platform_id) external view override returns (string memory) {
        return "";
    }

    function getPlatforOrigin(bytes32 platform_id) external view override returns (string memory) {
        return "";
    }
}
