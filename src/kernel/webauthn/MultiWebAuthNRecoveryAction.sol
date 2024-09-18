// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {MultiWebAuthNValidatorV2} from "./MultiWebAuthNValidator.sol";

/// @author @KONFeature
/// @title MultiWebAuthNRecoveryAction
/// @notice A smart contract used to perform the recovery on a smart account using WebAuthN signatures.
contract MultiWebAuthNRecoveryAction {
    /// @dev The validator on which the recovery will be performed
    MultiWebAuthNValidatorV2 private immutable webAuthNValidator;

    /// @dev Simple constructor, setting the validator address
    constructor(address _webAuthNValidator) {
        webAuthNValidator = MultiWebAuthNValidatorV2(_webAuthNValidator);
    }

    /// @dev Perform the passkey addition recovery
    function doAddPasskey(bytes32 authenticatorId, uint256 x, uint256 y) public {
        webAuthNValidator.addPassKey(authenticatorId, x, y);
    }
}
