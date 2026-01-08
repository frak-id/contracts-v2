// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {CampaignBank} from "./CampaignBank.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @author @KONFeature
/// @title CampaignBankFactory
/// @notice Factory for deploying CampaignBank contracts for merchants
/// @custom:security-contact contact@frak.id
contract CampaignBankFactory {
    using LibClone for address;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a new bank is deployed
    event BankDeployed(address indexed owner, address indexed bank);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when the RewarderHub is not set
    error InvalidRewarderHub();

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev The RewarderHub address
    address public immutable REWARDER_HUB;

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Create a new CampaignBankFactory
    /// @param _rewarderHub The RewarderHub address
    constructor(address _rewarderHub) {
        if (_rewarderHub == address(0)) revert InvalidRewarderHub();
        REWARDER_HUB = _rewarderHub;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Factory Functions                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Deploy a new CampaignBank for a merchant
    /// @param _owner The owner of the bank (merchant)
    /// @return bank The deployed bank address
    function deployBank(address _owner) external returns (CampaignBank bank) {
        bank = new CampaignBank(_owner, REWARDER_HUB);
        emit BankDeployed(_owner, address(bank));
    }

    /// @notice Deploy a new CampaignBank with a deterministic address
    /// @param _owner The owner of the bank (merchant)
    /// @param _salt Salt for CREATE2
    /// @return bank The deployed bank address
    function deployBank(address _owner, bytes32 _salt) external returns (CampaignBank bank) {
        bank = new CampaignBank{salt: _salt}(_owner, REWARDER_HUB);
        emit BankDeployed(_owner, address(bank));
    }

    /// @notice Predict the address of a bank deployed with CREATE2
    /// @param _owner The owner of the bank
    /// @param _salt Salt for CREATE2
    /// @return The predicted address
    function predictBankAddress(address _owner, bytes32 _salt) external view returns (address) {
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(type(CampaignBank).creationCode, abi.encode(_owner, REWARDER_HUB))
        );
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, bytecodeHash))))
        );
    }
}
