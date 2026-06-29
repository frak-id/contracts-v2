// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../Base.sol";
import {CampaignBankHandler} from "./CampaignBankHandler.sol";
import {RewarderHubHandler} from "./RewarderHubHandler.sol";
import {mUSDTokenHandler} from "./mUSDTokenHandler.sol";

/// @notice Inherits from all the handlers to expose all entry points in a single contract.
///         Manages environment changes (e.g. current actor, current token, mocks setup, etc.).
abstract contract Handlers is
    CampaignBankHandler,
    RewarderHubHandler,
    mUSDTokenHandler
{
    function setCurrentActor(uint256 entropy) public {
        actor = actors[entropy % actors.length];
    }
}
