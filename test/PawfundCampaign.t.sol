// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {IERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/IERC20.sol";

import {PawfundCampaign} from "../src/PawfundCampaign.sol";
import {PawfundFactory} from "../src/PawfundFactory.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract PawfundCampaignTest is Test {
    event DonationReceived(address indexed donor, uint256 amount, uint256 totalDonated);
    event Withdrawal(address indexed fundraiser, uint256 amount, uint256 totalWithdrawn);
    event CampaignCancelled(address indexed fundraiser, uint256 refundLiability);
    event RefundClaimed(address indexed donor, uint256 amount, uint256 totalRefunded);

    uint256 internal constant START_AT = 1_900_000_000;
    uint256 internal constant GOAL_AMOUNT = 1_000e6;
    uint256 internal constant END_AT = START_AT + 30 days;
    uint256 internal constant DONOR_BALANCE = 10_000e6;

    address internal owner;
    address internal fundraiser;
    address internal donor;
    address internal secondDonor;
    address internal stranger;

    MockUSDC internal usdc;
    PawfundCampaign internal campaign;

    function setUp() external {
        vm.warp(START_AT);

        owner = makeAddr("owner");
        fundraiser = makeAddr("fundraiser");
        donor = makeAddr("donor");
        secondDonor = makeAddr("secondDonor");
        stranger = makeAddr("stranger");

        usdc = new MockUSDC();
        PawfundFactory factory = new PawfundFactory(owner, usdc);

        vm.prank(owner);
        campaign = PawfundCampaign(factory.createCampaign(fundraiser, GOAL_AMOUNT, END_AT));

        usdc.mint(donor, DONOR_BALANCE);
        usdc.mint(secondDonor, DONOR_BALANCE);
    }

    function test_DonateTransfersUSDCAndEmitsEvent() external {
        uint256 amount = 250e6;

        vm.startPrank(donor);
        usdc.approve(address(campaign), amount);

        vm.expectEmit(true, false, false, true, address(campaign));
        emit DonationReceived(donor, amount, amount);
        campaign.donate(amount);
        vm.stopPrank();

        assertEq(usdc.balanceOf(donor), DONOR_BALANCE - amount);
        assertEq(usdc.balanceOf(address(campaign)), amount);
        assertEq(campaign.availableBalance(), amount);
        assertEq(campaign.totalDonated(), amount);
        assertEq(campaign.donatedAmount(donor), amount);
        assertEq(campaign.refundableAmount(donor), amount);
        assertEq(campaign.refundLiability(), amount);
    }

    function test_MultipleDonorsAccumulateTotalDonated() external {
        _donate(donor, 100e6);
        _donate(secondDonor, 400e6);

        assertEq(campaign.totalDonated(), 500e6);
        assertEq(campaign.availableBalance(), 500e6);
        assertEq(campaign.donatedAmount(donor), 100e6);
        assertEq(campaign.donatedAmount(secondDonor), 400e6);
    }

    function test_DonationMayExceedGoal() external {
        uint256 amount = GOAL_AMOUNT + 1;
        _donate(donor, amount);

        assertEq(campaign.totalDonated(), amount);
        assertGt(campaign.totalDonated(), campaign.goalAmount());
    }

    function test_RevertWhen_USDCIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.InvalidUSDC.selector, address(0)));
        new PawfundCampaign(MockUSDC(address(0)), fundraiser, GOAL_AMOUNT, END_AT);
    }

    function test_RevertWhen_USDCIsNotAContract() external {
        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.InvalidUSDC.selector, stranger));
        new PawfundCampaign(MockUSDC(stranger), fundraiser, GOAL_AMOUNT, END_AT);
    }

    function test_DonateAtLastSecond() external {
        vm.warp(END_AT - 1);
        _donate(donor, 1e6);

        assertEq(campaign.totalDonated(), 1e6);
    }

    function test_RevertWhen_DonatingAtEndAt() external {
        vm.warp(END_AT);

        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.CampaignClosed.selector, END_AT));
        vm.prank(donor);
        campaign.donate(1e6);
    }

    function test_RevertWhen_DonationIsZero() external {
        vm.expectRevert(PawfundCampaign.ZeroAmount.selector);
        vm.prank(donor);
        campaign.donate(0);
    }

    function test_RevertWhen_DonationHasNoAllowance() external {
        vm.expectRevert();
        vm.prank(donor);
        campaign.donate(1e6);
    }

    function test_RevertWhen_DonorBalanceIsInsufficient() external {
        uint256 amount = DONOR_BALANCE + 1;

        vm.prank(donor);
        usdc.approve(address(campaign), amount);

        vm.expectRevert();
        vm.prank(donor);
        campaign.donate(amount);
    }

    function test_FundraiserCanCancelCampaignAndEnableRefunds() external {
        _donate(donor, 100e6);
        _donate(secondDonor, 400e6);

        vm.expectEmit(true, false, false, true, address(campaign));
        emit CampaignCancelled(fundraiser, 500e6);

        vm.prank(fundraiser);
        campaign.cancelCampaign();

        assertTrue(campaign.cancelled());
        assertEq(campaign.refundLiability(), 500e6);
        assertEq(campaign.withdrawableBalance(), 0);
    }

    function test_FundraiserCanCancelCampaignAfterEndAt() external {
        _donate(donor, 100e6);
        vm.warp(END_AT + 1);

        vm.prank(fundraiser);
        campaign.cancelCampaign();

        assertTrue(campaign.cancelled());
    }

    function test_FundraiserCanCancelCampaignWithoutDonations() external {
        vm.prank(fundraiser);
        campaign.cancelCampaign();

        assertTrue(campaign.cancelled());
        assertEq(campaign.refundLiability(), 0);
        assertEq(campaign.withdrawableBalance(), 0);
    }

    function test_RevertWhen_NonFundraiserCancelsCampaign() external {
        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.UnauthorizedFundraiser.selector, stranger));
        vm.prank(stranger);
        campaign.cancelCampaign();
    }

    function test_RevertWhen_CancellingCampaignAgain() external {
        vm.prank(fundraiser);
        campaign.cancelCampaign();

        vm.expectRevert(PawfundCampaign.CampaignAlreadyCancelled.selector);
        vm.prank(fundraiser);
        campaign.cancelCampaign();
    }

    function test_RevertWhen_CancellationIsUnderfunded() external {
        _donate(donor, 500e6);

        vm.prank(fundraiser);
        campaign.withdraw(200e6);

        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.InsufficientRefundFunding.selector, 300e6, 500e6));
        vm.prank(fundraiser);
        campaign.cancelCampaign();

        assertFalse(campaign.cancelled());
    }

    function test_FundraiserCanRestoreFundingAndCancelCampaign() external {
        _donate(donor, 500e6);

        vm.startPrank(fundraiser);
        campaign.withdraw(200e6);
        assertTrue(usdc.transfer(address(campaign), 200e6));
        campaign.cancelCampaign();
        vm.stopPrank();

        assertTrue(campaign.cancelled());
        assertEq(campaign.availableBalance(), 500e6);
        assertEq(campaign.refundLiability(), 500e6);
    }

    function test_RevertWhen_DonatingAfterCancellation() external {
        vm.prank(fundraiser);
        campaign.cancelCampaign();

        vm.expectRevert(PawfundCampaign.CampaignIsCancelled.selector);
        vm.prank(donor);
        campaign.donate(1e6);
    }

    function test_DonorClaimsFullRefundAcrossDonations() external {
        _donate(donor, 100e6);
        _donate(donor, 150e6);

        vm.prank(fundraiser);
        campaign.cancelCampaign();

        vm.expectEmit(true, false, false, true, address(campaign));
        emit RefundClaimed(donor, 250e6, 250e6);

        vm.prank(donor);
        campaign.claimRefund();

        assertEq(usdc.balanceOf(donor), DONOR_BALANCE);
        assertEq(campaign.donatedAmount(donor), 250e6);
        assertEq(campaign.refundedAmount(donor), 250e6);
        assertEq(campaign.refundableAmount(donor), 0);
        assertEq(campaign.totalRefunded(), 250e6);
        assertEq(campaign.refundLiability(), 0);
        assertEq(campaign.availableBalance(), 0);
    }

    function test_MultipleDonorsCanClaimInAnyOrder() external {
        _donate(donor, 100e6);
        _donate(secondDonor, 400e6);

        vm.prank(fundraiser);
        campaign.cancelCampaign();

        vm.prank(secondDonor);
        campaign.claimRefund();

        assertEq(campaign.totalRefunded(), 400e6);
        assertEq(campaign.refundLiability(), 100e6);
        assertEq(campaign.availableBalance(), 100e6);

        vm.prank(donor);
        campaign.claimRefund();

        assertEq(campaign.totalRefunded(), 500e6);
        assertEq(campaign.refundLiability(), 0);
        assertEq(campaign.availableBalance(), 0);
    }

    function test_RevertWhen_ClaimingBeforeCancellation() external {
        _donate(donor, 100e6);

        vm.expectRevert(PawfundCampaign.RefundsNotEnabled.selector);
        vm.prank(donor);
        campaign.claimRefund();
    }

    function test_RevertWhen_AddressHasNoRefundAvailable() external {
        vm.prank(fundraiser);
        campaign.cancelCampaign();

        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.NoRefundAvailable.selector, stranger));
        vm.prank(stranger);
        campaign.claimRefund();
    }

    function test_RevertWhen_ClaimingRefundTwice() external {
        _donate(donor, 100e6);

        vm.prank(fundraiser);
        campaign.cancelCampaign();
        vm.prank(donor);
        campaign.claimRefund();

        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.NoRefundAvailable.selector, donor));
        vm.prank(donor);
        campaign.claimRefund();
    }

    function test_RefundTransferFailureRollsBackAccounting() external {
        uint256 amount = 100e6;
        _donate(donor, amount);

        vm.prank(fundraiser);
        campaign.cancelCampaign();

        vm.mockCallRevert(
            address(usdc),
            abi.encodeWithSelector(IERC20.transfer.selector, donor, amount),
            abi.encode("transfer failed")
        );
        vm.expectRevert();
        vm.prank(donor);
        campaign.claimRefund();

        assertEq(campaign.refundedAmount(donor), 0);
        assertEq(campaign.totalRefunded(), 0);
        assertEq(campaign.refundableAmount(donor), amount);
        assertEq(campaign.refundLiability(), amount);
    }

    function test_FundraiserCanWithdrawBeforeCampaignEnds() external {
        _donate(donor, 500e6);
        uint256 amount = 200e6;

        vm.expectEmit(true, false, false, true, address(campaign));
        emit Withdrawal(fundraiser, amount, amount);

        vm.prank(fundraiser);
        campaign.withdraw(amount);

        assertEq(usdc.balanceOf(fundraiser), amount);
        assertEq(campaign.availableBalance(), 300e6);
        assertEq(campaign.totalWithdrawn(), amount);
        assertEq(campaign.totalDonated(), 500e6);
    }

    function test_FundraiserCanWithdrawAfterCampaignEnds() external {
        _donate(donor, 500e6);
        vm.warp(END_AT + 1);

        vm.prank(fundraiser);
        campaign.withdraw(500e6);

        assertEq(usdc.balanceOf(fundraiser), 500e6);
        assertEq(campaign.availableBalance(), 0);
    }

    function test_RevertWhen_NonFundraiserWithdraws() external {
        _donate(donor, 100e6);

        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.UnauthorizedFundraiser.selector, stranger));
        vm.prank(stranger);
        campaign.withdraw(1e6);
    }

    function test_RevertWhen_WithdrawalIsZero() external {
        vm.expectRevert(PawfundCampaign.ZeroAmount.selector);
        vm.prank(fundraiser);
        campaign.withdraw(0);
    }

    function test_RevertWhen_WithdrawalExceedsBalance() external {
        _donate(donor, 100e6);

        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.InsufficientBalance.selector, 100e6, 100e6 + 1));
        vm.prank(fundraiser);
        campaign.withdraw(100e6 + 1);
    }

    function test_DonationsRemainCumulativeAfterWithdrawal() external {
        _donate(donor, 400e6);

        vm.prank(fundraiser);
        campaign.withdraw(150e6);

        _donate(secondDonor, 100e6);

        assertEq(campaign.totalDonated(), 500e6);
        assertEq(campaign.totalWithdrawn(), 150e6);
        assertEq(campaign.availableBalance(), 350e6);
    }

    function test_DirectUSDCTransferDoesNotCountAsDonationButCanBeWithdrawn() external {
        uint256 amount = 75e6;

        vm.prank(donor);
        assertTrue(usdc.transfer(address(campaign), amount));

        assertEq(campaign.totalDonated(), 0);
        assertEq(campaign.availableBalance(), amount);

        vm.prank(fundraiser);
        campaign.withdraw(amount);

        assertEq(usdc.balanceOf(fundraiser), amount);
        assertEq(campaign.totalWithdrawn(), amount);
    }

    function test_FundraiserCanOnlyWithdrawSurplusAfterCancellation() external {
        uint256 donation = 500e6;
        uint256 surplus = 75e6;
        _donate(donor, donation);

        vm.prank(secondDonor);
        assertTrue(usdc.transfer(address(campaign), surplus));

        vm.prank(fundraiser);
        campaign.cancelCampaign();

        assertEq(campaign.availableBalance(), donation + surplus);
        assertEq(campaign.refundLiability(), donation);
        assertEq(campaign.withdrawableBalance(), surplus);

        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.InsufficientBalance.selector, surplus, surplus + 1));
        vm.prank(fundraiser);
        campaign.withdraw(surplus + 1);

        vm.prank(fundraiser);
        campaign.withdraw(surplus);

        assertEq(campaign.availableBalance(), donation);
        assertEq(campaign.refundLiability(), donation);
        assertEq(campaign.withdrawableBalance(), 0);
        assertEq(campaign.totalWithdrawn(), surplus);
    }

    function test_DirectTransferAfterCancellationBecomesWithdrawableSurplus() external {
        _donate(donor, 100e6);

        vm.prank(fundraiser);
        campaign.cancelCampaign();
        vm.prank(secondDonor);
        assertTrue(usdc.transfer(address(campaign), 25e6));

        assertEq(campaign.refundLiability(), 100e6);
        assertEq(campaign.withdrawableBalance(), 25e6);
    }

    function testFuzz_Donate(uint96 rawAmount) external {
        uint256 amount = bound(uint256(rawAmount), 1, type(uint96).max);
        usdc.mint(donor, amount);

        _donate(donor, amount);

        assertEq(campaign.totalDonated(), amount);
        assertEq(campaign.availableBalance(), amount);
    }

    function testFuzz_PartialWithdrawal(uint96 rawDonation, uint96 rawWithdrawal) external {
        uint256 donation = bound(uint256(rawDonation), 1, type(uint96).max);
        uint256 withdrawal = bound(uint256(rawWithdrawal), 1, donation);
        usdc.mint(donor, donation);
        _donate(donor, donation);

        vm.prank(fundraiser);
        campaign.withdraw(withdrawal);

        assertEq(campaign.totalDonated(), donation);
        assertEq(campaign.totalWithdrawn(), withdrawal);
        assertEq(campaign.availableBalance(), donation - withdrawal);
        assertEq(usdc.balanceOf(fundraiser), withdrawal);
    }

    function testFuzz_ClaimFullRefund(uint96 rawDonation) external {
        uint256 donation = bound(uint256(rawDonation), 1, type(uint96).max);
        usdc.mint(donor, donation);
        _donate(donor, donation);

        vm.prank(fundraiser);
        campaign.cancelCampaign();
        vm.prank(donor);
        campaign.claimRefund();

        assertEq(campaign.totalRefunded(), donation);
        assertEq(campaign.refundedAmount(donor), donation);
        assertEq(campaign.refundLiability(), 0);
        assertEq(campaign.availableBalance(), 0);
    }

    function _donate(address from, uint256 amount) internal {
        vm.startPrank(from);
        usdc.approve(address(campaign), amount);
        campaign.donate(amount);
        vm.stopPrank();
    }
}
