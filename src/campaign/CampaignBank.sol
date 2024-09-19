// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {CAMPAIGN_MANAGER_ROLE, PRODUCT_MANAGER_ROLE} from "../constants/Roles.sol";
import {PushPullModule, Reward} from "../modules/PushPullModule.sol";
import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @author @KONFeature
/// @title CampaignBank
/// @notice Contract managing the banking system for campaigns around a product
/// @custom:security-contact contact@frak.id
contract CampaignBank is PushPullModule {
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error Unauthorized();
    error BankIsntOpen();
    error BankIsStillOpen();

    /// @dev The distribution period
    uint256 private immutable PRODUCT_ID;

    /// @dev The product administrator registry
    ProductAdministratorRegistry private immutable PRODUCT_ADMINISTRATOR_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.campaign.bank')) - 1)
    bytes32 private constant _CAMPAIGN_BANK_STORAGE_SLOT =
        0x356c46682aa739dec7305c374b700a77a506ccd0aed5d54b846830f6bb4f4180;

    /// @custom:storage-location erc7201:frak.campaign.bank
    struct CampaignBankStorage {
        /// @dev Is the bank active or not (could be frozen, thus no distribution)
        bool isDistributionEnable;
        /// @dev Mapping of campaign to the allowed distribution state
        mapping(address campaign => bool allowedToDistribute) allowedCampaign;
    }

    function _campaignBankStorage() internal pure returns (CampaignBankStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _CAMPAIGN_BANK_STORAGE_SLOT
        }
    }

    /// @dev Construct a new campaign bank
    constructor(ProductAdministratorRegistry _adminRegistry, uint256 _productId, address _token)
        PushPullModule(_token)
    {
        PRODUCT_ADMINISTRATOR_REGISTRY = _adminRegistry;
        PRODUCT_ID = _productId;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Rewards pushing                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Push multiple rewards
    /// @param _rewards Rewards to be pushed
    function pushRewards(Reward[] calldata _rewards) external onlyApprovedCampaign {
        if (!_campaignBankStorage().isDistributionEnable) revert BankIsntOpen();
        _pushRewards(_rewards);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Roles management                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Update a campaign allowance for token distribution
    /// @param _campaign The campaign to approve
    function updateCampaignAllowance(address _campaign, bool _isAllowed) external onlyAllowedCampaignManager {
        _campaignBankStorage().allowedCampaign[_campaign] = _isAllowed;
    }

    /// @notice Update the distribution state
    function updateDistributionState(bool _state) external onlyAllowedProductManager {
        _campaignBankStorage().isDistributionEnable = _state;
    }

    /// @dev Withdraw the remaining token from the campaign
    function withdraw() external nonReentrant onlyAllowedProductManager {
        if (_campaignBankStorage().isDistributionEnable) revert BankIsStillOpen();

        // Compute the amount withdrawable
        uint256 pendingAmount = getTotalPending();
        uint256 withdrawable = TOKEN.balanceOf(address(this)) - pendingAmount;

        // Withdraw the amount
        TOKEN.safeTransfer(msg.sender, withdrawable);
    }

    /* -------------------------------------------------------------------------- */
    /*                                View methods                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Check if the campaign is allowed for distribution
    function isCampaignAllowed(address _campaign) external view returns (bool) {
        return _campaignBankStorage().allowedCampaign[_campaign];
    }

    /// @notice Check if the distribution is enabled
    function isDistributionEnabled() external view returns (bool) {
        return _campaignBankStorage().isDistributionEnable;
    }

    /// @notice Check if the campaign is able to distribute tokens
    function isAbleToDistributeForCampaign(address _campaign) external view returns (bool) {
        CampaignBankStorage storage bankStorage = _campaignBankStorage();

        // Check from the storage first
        if (!bankStorage.allowedCampaign[_campaign] || !bankStorage.isDistributionEnable) return false;

        // Then check if we got enough token
        return TOKEN.balanceOf(address(this)) > getTotalPending();
    }

    /// @notice Get config info
    function getConfig() external view returns (uint256 productId, address token) {
        return (PRODUCT_ID, address(TOKEN));
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper modifiers                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Only allow the call for an authorised mananger
    modifier onlyAllowedCampaignManager() {
        bool isAllowed =
            PRODUCT_ADMINISTRATOR_REGISTRY.hasAllRolesOrAdmin(PRODUCT_ID, msg.sender, CAMPAIGN_MANAGER_ROLE);
        if (!isAllowed) revert Unauthorized();
        _;
    }

    /// @dev Only allow the call for an authorised mananger
    modifier onlyAllowedProductManager() {
        bool isAllowed = PRODUCT_ADMINISTRATOR_REGISTRY.hasAllRolesOrAdmin(PRODUCT_ID, msg.sender, PRODUCT_MANAGER_ROLE);
        if (!isAllowed) revert Unauthorized();
        _;
    }

    /// @dev Only allow the call for an authorised mananger
    modifier onlyApprovedCampaign() {
        if (!_campaignBankStorage().allowedCampaign[msg.sender]) revert Unauthorized();
        _;
    }
}
