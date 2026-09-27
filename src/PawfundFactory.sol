// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Ownable} from "@openzeppelin-contracts-5.6.1/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin-contracts-5.6.1/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/IERC20.sol";

import {PawfundCampaign} from "./PawfundCampaign.sol";

/// @title PawfundFactory
/// @notice Deploys official Pawfund campaigns for an authorized operator.
contract PawfundFactory is Ownable2Step {
    error InvalidCampaignId();
    error InvalidUSDC(address token);
    error OwnershipRenunciationDisabled();
    error CampaignAlreadyDeployed(bytes16 campaignId, address campaign);

    event CampaignCreated(
        bytes16 indexed campaignId,
        address indexed campaign,
        address indexed fundraiser,
        uint256 goalAmount,
        uint256 endAt
    );

    IERC20 public immutable usdc;

    /// @notice Campaign deployed for a backend id, or zero when that id has not been deployed.
    mapping(bytes16 campaignId => address campaign) public campaignAddresses;

    constructor(address initialOwner, IERC20 usdc_) Ownable(initialOwner) {
        address token = address(usdc_);
        if (token == address(0) || token.code.length == 0) {
            revert InvalidUSDC(token);
        }

        usdc = usdc_;
    }

    /// @notice Deploy an official Pawfund campaign.
    /// @dev Reverts with `CampaignAlreadyDeployed` when `campaignId` already has a campaign.
    ///      Read `campaignAddresses` or the error data for the existing address. The call is not idempotent.
    function createCampaign(bytes16 campaignId, address fundraiser, uint256 goalAmount, uint256 endAt)
        external
        onlyOwner
        returns (address campaign)
    {
        if (campaignId == bytes16(0)) {
            revert InvalidCampaignId();
        }

        address existing = campaignAddresses[campaignId];
        if (existing != address(0)) revert CampaignAlreadyDeployed(campaignId, existing);

        campaign = address(new PawfundCampaign(usdc, fundraiser, goalAmount, endAt));
        campaignAddresses[campaignId] = campaign;

        emit CampaignCreated(campaignId, campaign, fundraiser, goalAmount, endAt);
    }

    /// @dev Ownership must always remain assigned so campaign creation cannot be bricked.
    function renounceOwnership() public pure override {
        revert OwnershipRenunciationDisabled();
    }
}
