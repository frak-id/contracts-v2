// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {MINTER_ROLES} from "../utils/Roles.sol";

/// @author @KONFeature
/// @title PaywallFrk
/// @notice pFrak token, used to unlock access to content for a paywall
contract PaywallFrk is ERC20, OwnableRoles {


    constructor(address _owner) {
        _initializeOwner(_owner);
        _setRoles(_owner, MINTER_ROLES);
    }

    /// @dev Mint some pFrk to the given address
    function mint(address _to, uint256 _amount) public onlyRoles(MINTER_ROLES) {
        _mint(_to, _amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                    Token description for external tools                    */
    /* -------------------------------------------------------------------------- */

    function name() public pure override returns (string memory) {
        return "Paywall FRAK";
    }

    function symbol() public pure override returns (string memory) {
        return "pFRK";
    }
}
