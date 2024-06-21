// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

interface IContentConsumptionContract {
    function pushCcu(bytes32 platform_id, uint256 added_consumption, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function getUserConsumption(address user) external view returns (uint256);

    function getTotalConsumption() external view returns (uint256);

    function domainSeparator() external view returns (bytes32);
}

contract StylusFlattened is IContentConsumptionContract {
    function pushCcu(bytes32 platform_id, uint256 added_consumption, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        override
    {}

    function domainSeparator() external pure override returns (bytes32) {
        return 0;
    }

    function getTotalConsumption() external pure override returns (uint256) {
        return 0;
    }

    function getUserConsumption(address) external pure override returns (uint256) {
        return 0;
    }
}
