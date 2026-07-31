// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Ownable} from "@openzeppelin-contracts-5.6.1/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin-contracts-5.6.1/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/IERC20.sol";

import {PawfundCampaign} from "./PawfundCampaign.sol";

/// @title PawfundFactory
/// @notice Deploys official Pawfund campaigns for an authorized operator.
contract PawfundFactory is Ownable2Step {
    error InvalidUSDC(address token);
    error OwnershipRenunciationDisabled();

    event CampaignCreated(address indexed campaign, address indexed fundraiser, uint256 goalAmount, uint256 endAt);

    IERC20 public immutable usdc;

    constructor(address initialOwner, IERC20 usdc_) Ownable(initialOwner) {
        address token = address(usdc_);
        if (token == address(0) || token.code.length == 0) {
            revert InvalidUSDC(token);
        }

        usdc = usdc_;
    }

    /// @notice Deploy an official Pawfund campaign.
    function createCampaign(address fundraiser, uint256 goalAmount, uint256 endAt)
        external
        onlyOwner
        returns (address campaign)
    {
        campaign = address(new PawfundCampaign(usdc, fundraiser, goalAmount, endAt));

        emit CampaignCreated(campaign, fundraiser, goalAmount, endAt);
    }

    /// @dev Ownership must always remain assigned so campaign creation cannot be bricked.
    function renounceOwnership() public pure override {
        revert OwnershipRenunciationDisabled();
    }
}
