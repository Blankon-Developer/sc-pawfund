// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {Ownable} from "@openzeppelin-contracts-5.6.1/access/Ownable.sol";

import {PawfundCampaign} from "../src/PawfundCampaign.sol";
import {PawfundFactory} from "../src/PawfundFactory.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract PawfundFactoryTest is Test {
    event CampaignCreated(address indexed campaign, address indexed fundraiser, uint256 goalAmount, uint256 endAt);

    uint256 internal constant START_AT = 1_900_000_000;
    uint256 internal constant GOAL_AMOUNT = 10_000e6;
    uint256 internal constant END_AT = START_AT + 30 days;

    address internal owner;
    address internal newOwner;
    address internal fundraiser;
    address internal stranger;

    MockUSDC internal usdc;
    PawfundFactory internal factory;

    function setUp() external {
        vm.warp(START_AT);

        owner = makeAddr("owner");
        newOwner = makeAddr("newOwner");
        fundraiser = makeAddr("fundraiser");
        stranger = makeAddr("stranger");

        usdc = new MockUSDC();
        factory = new PawfundFactory(owner, usdc);
    }

    function test_InitialState() external view {
        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), address(0));
        assertEq(address(factory.usdc()), address(usdc));
    }

    function test_CreateCampaignReturnsConfiguredCampaign() external {
        vm.prank(owner);
        address campaignAddress = factory.createCampaign(fundraiser, GOAL_AMOUNT, END_AT);

        PawfundCampaign campaign = PawfundCampaign(campaignAddress);
        assertEq(address(campaign.usdc()), address(usdc));
        assertEq(campaign.fundraiser(), fundraiser);
        assertEq(campaign.goalAmount(), GOAL_AMOUNT);
        assertEq(campaign.endAt(), END_AT);
        assertEq(campaign.totalDonated(), 0);
        assertEq(campaign.totalWithdrawn(), 0);
        assertEq(campaign.totalRefunded(), 0);
        assertFalse(campaign.cancelled());
        assertEq(campaign.refundLiability(), 0);
        assertEq(campaign.withdrawableBalance(), 0);
    }

    function test_CreateCampaignEmitsEvent() external {
        vm.expectEmit(false, true, false, true, address(factory));
        emit CampaignCreated(address(0), fundraiser, GOAL_AMOUNT, END_AT);

        vm.prank(owner);
        factory.createCampaign(fundraiser, GOAL_AMOUNT, END_AT);
    }

    function test_RevertWhen_NonOwnerCreatesCampaign() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

        vm.prank(stranger);
        factory.createCampaign(fundraiser, GOAL_AMOUNT, END_AT);
    }

    function test_RevertWhen_FundraiserIsZero() external {
        vm.expectRevert(PawfundCampaign.InvalidFundraiser.selector);

        vm.prank(owner);
        factory.createCampaign(address(0), GOAL_AMOUNT, END_AT);
    }

    function test_RevertWhen_GoalAmountIsZero() external {
        vm.expectRevert(PawfundCampaign.InvalidGoalAmount.selector);

        vm.prank(owner);
        factory.createCampaign(fundraiser, 0, END_AT);
    }

    function test_RevertWhen_EndAtIsNotInFuture() external {
        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.InvalidEndAt.selector, START_AT));

        vm.prank(owner);
        factory.createCampaign(fundraiser, GOAL_AMOUNT, START_AT);
    }

    function test_OwnershipTransferRequiresAcceptance() external {
        vm.prank(owner);
        factory.transferOwnership(newOwner);

        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), newOwner);

        vm.prank(newOwner);
        factory.acceptOwnership();

        assertEq(factory.owner(), newOwner);
        assertEq(factory.pendingOwner(), address(0));
    }

    function test_RevertWhen_RenouncingOwnership() external {
        vm.expectRevert(PawfundFactory.OwnershipRenunciationDisabled.selector);

        vm.prank(owner);
        factory.renounceOwnership();
    }

    function test_RevertWhen_USDCIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(PawfundFactory.InvalidUSDC.selector, address(0)));
        new PawfundFactory(owner, MockUSDC(address(0)));
    }

    function test_RevertWhen_USDCIsNotAContract() external {
        vm.expectRevert(abi.encodeWithSelector(PawfundFactory.InvalidUSDC.selector, stranger));
        new PawfundFactory(owner, MockUSDC(stranger));
    }
}
