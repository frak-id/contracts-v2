// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev The role required to mint stuff
uint256 constant MINTER_ROLE = 1 << 0;

/// @dev The role required to upgrade stuff
uint256 constant UPGRADE_ROLE = 1 << 1;

/* -------------------------------------------------------------------------- */
/*                               Product related                              */
/* -------------------------------------------------------------------------- */

/// @dev The role that can validate a user interaction
uint256 constant INTERCATION_VALIDATOR_ROLE = 1 << 4;
