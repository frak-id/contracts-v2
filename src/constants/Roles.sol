// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev The role required to mint stuff (either pFrk or new contents)
uint256 constant MINTER_ROLES = 1 << 0;

/// @dev The role for the campaign manager
uint256 constant CAMPAIGN_MANAGER_ROLES = 2 << 0;
