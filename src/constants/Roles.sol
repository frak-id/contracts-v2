// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev The role required to upgrade stuff
uint256 constant UPGRADE_ROLE = 1 << 0;

/// @dev The role that can push/lock rewards
uint256 constant REWARDER_ROLE = 1 << 1;

/// @dev The role that can resolve userIds to wallets
uint256 constant RESOLVER_ROLE = 1 << 2;
