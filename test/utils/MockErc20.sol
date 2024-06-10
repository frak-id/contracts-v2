// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solady/tokens/ERC20.sol";

contract MockErc20 is ERC20 {
    /// @dev Returns the name of the token.
    function name() public pure override returns (string memory) {
        return "Mock-ERC20";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public pure override returns (string memory) {
        return "MOCK";
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
