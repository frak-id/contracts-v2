// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Initializable} from "solady/utils/Initializable.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @dev The role required to manage the bank (deposit, withdraw, update state)
uint256 constant CAMPAIGN_BANK_MANAGER_ROLE = 1 << 0;

/// @author @KONFeature
/// @title CampaignBank
/// @notice Multi-token bank contract for merchants to fund reward campaigns
/// @dev Each merchant has one bank that can hold multiple tokens and authorize the RewarderHub
/// @custom:security-contact contact@frak.id
contract CampaignBank is OwnableRoles, Initializable {
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a token allowance is updated for the RewarderHub
    event AllowanceUpdated(address indexed token, uint256 amount);

    /// @dev Emitted when the distribution state is updated
    event DistributionStateUpdated(bool isDistributing);

    /// @dev Emitted when tokens are deposited
    event Deposited(address indexed token, uint256 amount);

    /// @dev Emitted when tokens are withdrawn
    event Withdrawn(address indexed token, uint256 amount, address to);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when trying to distribute while bank is closed
    error BankIsClosed();

    /// @dev Error when trying to withdraw while bank is open
    error BankIsStillOpen();

    /// @dev Error when trying to set zero address
    error InvalidAddress();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.bank.campaign')) - 1)
    bytes32 private constant _CAMPAIGN_BANK_STORAGE_SLOT =
        0x8a2c3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b;

    /// @custom:storage-location erc7201:frak.bank.campaign
    struct CampaignBankStorage {
        /// @dev The RewarderHub address that can pull funds
        address rewarderHub;
        /// @dev Is the bank open for distribution
        bool isDistributionEnabled;
    }

    /// @notice Get the RewarderHub address
    function REWARDER_HUB() public view returns (address) {
        return _storage().rewarderHub;
    }

    function _storage() private pure returns (CampaignBankStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _CAMPAIGN_BANK_STORAGE_SLOT
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */

    /// @dev Disable initializers on implementation contract
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize a new CampaignBank
    /// @param _owner The owner of the bank (merchant)
    /// @param _rewarderHub The RewarderHub address that will pull funds
    function init(address _owner, address _rewarderHub) external initializer {
        if (_rewarderHub == address(0)) revert InvalidAddress();

        _initializeOwner(_owner);
        _setRoles(_owner, CAMPAIGN_BANK_MANAGER_ROLE);

        _storage().rewarderHub = _rewarderHub;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Distribution Control                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Update the distribution state (open/close the bank)
    /// @param _enabled Whether distribution should be enabled
    function setDistributionState(bool _enabled) external onlyRolesOrOwner(CAMPAIGN_BANK_MANAGER_ROLE) {
        _storage().isDistributionEnabled = _enabled;
        emit DistributionStateUpdated(_enabled);
    }

    /// @notice Check if distribution is enabled
    function isDistributionEnabled() external view returns (bool) {
        return _storage().isDistributionEnabled;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Allowance Management                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Update the allowance for a token to the RewarderHub
    /// @param _token The token address
    /// @param _amount The allowance amount
    function updateAllowance(address _token, uint256 _amount) external onlyRolesOrOwner(CAMPAIGN_BANK_MANAGER_ROLE) {
        CampaignBankStorage storage $ = _storage();
        if (!$.isDistributionEnabled) revert BankIsClosed();

        _token.safeApprove($.rewarderHub, _amount);
        emit AllowanceUpdated(_token, _amount);
    }

    /// @notice Update allowances for multiple tokens at once
    /// @param _tokens Array of token addresses
    /// @param _amounts Array of allowance amounts
    function updateAllowances(address[] calldata _tokens, uint256[] calldata _amounts)
        external
        onlyRolesOrOwner(CAMPAIGN_BANK_MANAGER_ROLE)
    {
        CampaignBankStorage storage $ = _storage();
        if (!$.isDistributionEnabled) revert BankIsClosed();

        address rewarderHub = $.rewarderHub;
        for (uint256 i; i < _tokens.length;) {
            _tokens[i].safeApprove(rewarderHub, _amounts[i]);
            emit AllowanceUpdated(_tokens[i], _amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Get the current allowance for a token
    /// @param _token The token address
    /// @return The current allowance to RewarderHub
    function getAllowance(address _token) external view returns (uint256) {
        return _allowance(_token);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Deposit & Withdrawal                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Deposit tokens into the bank
    /// @param _token The token address
    /// @param _amount The amount to deposit
    function deposit(address _token, uint256 _amount) external onlyRolesOrOwner(CAMPAIGN_BANK_MANAGER_ROLE) {
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(_token, _amount);
    }

    /// @notice Withdraw tokens from the bank
    /// @dev Can only withdraw when distribution is disabled
    /// @param _token The token address
    /// @param _amount The amount to withdraw
    /// @param _to The recipient address
    function withdraw(address _token, uint256 _amount, address _to)
        external
        onlyRolesOrOwner(CAMPAIGN_BANK_MANAGER_ROLE)
    {
        if (_storage().isDistributionEnabled) revert BankIsStillOpen();
        if (_to == address(0)) revert InvalidAddress();

        _token.safeTransfer(_to, _amount);
        emit Withdrawn(_token, _amount, _to);
    }

    /// @notice Get the balance of a token in the bank
    /// @param _token The token address
    /// @return The token balance
    function getBalance(address _token) external view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /* -------------------------------------------------------------------------- */
    /*                            Emergency Functions                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Emergency revoke all allowances for a token
    /// @dev Can be called even when distribution is enabled
    /// @param _token The token address
    function revokeAllowance(address _token) external onlyOwner {
        _token.safeApprove(_storage().rewarderHub, 0);
        emit AllowanceUpdated(_token, 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Internal Functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Get allowance using low-level call to handle non-standard tokens
    function _allowance(address _token) internal view returns (uint256) {
        (bool success, bytes memory data) =
            _token.staticcall(abi.encodeWithSignature("allowance(address,address)", address(this), _storage().rewarderHub));
        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }
        return 0;
    }
}
