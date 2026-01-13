// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev The role required to upgrade stuff
uint256 constant UPGRADE_ROLE = 1 << 0;

/// @dev The role that can push/lock rewards
uint256 constant REWARDER_ROLE = 1 << 1;

/// @dev The role that can freeze users and recover frozen funds
uint256 constant COMPLIANCE_ROLE = 1 << 2;
