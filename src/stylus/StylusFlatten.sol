// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

interface IContentConsumptionContract {
    function pushCcu(bytes32 platform_id, uint256 added_consumption, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function domainSeparator() external view returns (bytes32);
}

contract StylusFlattened is IContentConsumptionContract {
    function pushCcu(bytes32 platform_id, uint256 added_consumption, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        override
    {}

    function domainSeparator() external view override returns (bytes32) {
        return 0;
    }
}
