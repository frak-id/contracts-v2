// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {MINTER_ROLE} from "../constants/Roles.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/// @author @KONFeature
/// @title mUSDToken
/// @notice mUSD token, mocked usd stablecoin token
/// @dev This is a mocked token for TESTING PURPOSE, DO NOT USE IN PROD
contract mUSDToken is ERC20, OwnableRoles {
    constructor(address _owner) {
        _initializeOwner(_owner);
        _setRoles(_owner, MINTER_ROLE);
    }

    /// @dev Mint some pFrk to the given address
    function mint(address _to, uint256 _amount) public onlyRoles(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                    Token description for external tools                    */
    /* -------------------------------------------------------------------------- */

    function name() public pure override returns (string memory) {
        return "Mocked USD";
    }

    function symbol() public pure override returns (string memory) {
        return "mUSD";
    }
}
