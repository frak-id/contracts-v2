// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {MINTER_ROLES} from "../constants/Roles.sol";

/// @author @KONFeature
/// @title ReferralToken
/// @notice rFrak token, used to airdrop on referral campaign
contract ReferralToken is ERC20, OwnableRoles {
    constructor(address _owner) {
        _initializeOwner(_owner);
        _setRoles(_owner, MINTER_ROLES);
    }

    /// @dev Mint some rFrk to the given address
    function mint(address _to, uint256 _amount) public onlyRoles(MINTER_ROLES) {
        _mint(_to, _amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                    Token description for external tools                    */
    /* -------------------------------------------------------------------------- */

    function name() public pure override returns (string memory) {
        return "Referral Token - FRAK";
    }

    function symbol() public pure override returns (string memory) {
        return "rFRK";
    }
}
