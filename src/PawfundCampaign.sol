// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.6.1/utils/ReentrancyGuard.sol";

/// @title PawfundCampaign
/// @notice Holds USDC donations for a single animal fundraising campaign.
contract PawfundCampaign is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidUSDC(address token);
    error InvalidFundraiser();
    error InvalidGoalAmount();
    error InvalidEndAt(uint256 endAt);
    error ZeroAmount();
    error CampaignClosed(uint256 endAt);
    error UnauthorizedFundraiser(address caller);
    error InsufficientBalance(uint256 available, uint256 requested);

    event DonationReceived(address indexed donor, uint256 amount, uint256 totalDonated);
    event Withdrawal(address indexed fundraiser, uint256 amount, uint256 totalWithdrawn);

    IERC20 public immutable usdc;
    address public immutable fundraiser;
    uint256 public immutable goalAmount;
    uint256 public immutable endAt;

    uint256 public totalDonated;
    uint256 public totalWithdrawn;

    constructor(IERC20 usdc_, address fundraiser_, uint256 goalAmount_, uint256 endAt_) {
        address token = address(usdc_);
        if (token == address(0) || token.code.length == 0) {
            revert InvalidUSDC(token);
        }
        if (fundraiser_ == address(0)) {
            revert InvalidFundraiser();
        }
        if (goalAmount_ == 0) {
            revert InvalidGoalAmount();
        }
        // forge-lint: disable-next-line(block-timestamp)
        if (endAt_ <= block.timestamp) {
            revert InvalidEndAt(endAt_);
        }

        usdc = usdc_;
        fundraiser = fundraiser_;
        goalAmount = goalAmount_;
        endAt = endAt_;
    }

    /// @notice Donate USDC to this campaign.
    /// @dev The caller must approve this contract to spend at least `amount` USDC.
    function donate(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= endAt) {
            revert CampaignClosed(endAt);
        }

        totalDonated += amount;
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit DonationReceived(msg.sender, amount, totalDonated);
    }

    /// @notice Withdraw donated USDC to the fundraiser wallet.
    function withdraw(uint256 amount) external nonReentrant {
        if (msg.sender != fundraiser) {
            revert UnauthorizedFundraiser(msg.sender);
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        uint256 available = availableBalance();
        if (amount > available) {
            revert InsufficientBalance(available, amount);
        }

        totalWithdrawn += amount;
        usdc.safeTransfer(fundraiser, amount);

        emit Withdrawal(fundraiser, amount, totalWithdrawn);
    }

    /// @notice Current amount of USDC held by this campaign.
    function availableBalance() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
}
