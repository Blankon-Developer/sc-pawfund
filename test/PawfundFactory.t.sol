// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {Ownable} from "@openzeppelin-contracts-5.6.1/access/Ownable.sol";

import {PawfundCampaign} from "../src/PawfundCampaign.sol";
import {PawfundFactory} from "../src/PawfundFactory.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract PawfundFactoryTest is Test {
    event CampaignCreated(
        bytes16 indexed campaignId,
        address indexed campaign,
        address indexed fundraiser,
        uint256 goalAmount,
        uint256 endAt
    );

    bytes16 internal constant CAMPAIGN_ID = 0x550e8400e29b41d4a716446655440000;
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
        address campaignAddress = factory.createCampaign(CAMPAIGN_ID, fundraiser, GOAL_AMOUNT, END_AT);

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
        assertEq(factory.campaignAddresses(CAMPAIGN_ID), campaignAddress);
    }

    function test_CreateCampaignEmitsEvent() external {
        address campaignAddress = vm.computeCreateAddress(address(factory), 1);

        vm.expectEmit(true, true, true, true, address(factory));
        emit CampaignCreated(CAMPAIGN_ID, campaignAddress, fundraiser, GOAL_AMOUNT, END_AT);

        vm.prank(owner);
        factory.createCampaign(CAMPAIGN_ID, fundraiser, GOAL_AMOUNT, END_AT);
    }

    function test_CreateCampaignAcceptsDistinctIds() external {
        bytes16 secondId = 0x550e8400e29b41d4a716446655440001;

        vm.startPrank(owner);
        address first = factory.createCampaign(CAMPAIGN_ID, fundraiser, GOAL_AMOUNT, END_AT);
        address second = factory.createCampaign(secondId, fundraiser, GOAL_AMOUNT, END_AT);
        vm.stopPrank();

        assertEq(factory.campaignAddresses(CAMPAIGN_ID), first);
        assertEq(factory.campaignAddresses(secondId), second);
        assertTrue(first != second);
    }

    function test_RevertWhen_CampaignAlreadyDeployed() external {
        vm.prank(owner);
        address existing = factory.createCampaign(CAMPAIGN_ID, fundraiser, GOAL_AMOUNT, END_AT);

        vm.expectRevert(abi.encodeWithSelector(PawfundFactory.CampaignAlreadyDeployed.selector, CAMPAIGN_ID, existing));

        vm.prank(owner);
        factory.createCampaign(CAMPAIGN_ID, fundraiser, GOAL_AMOUNT, END_AT);

        assertEq(factory.campaignAddresses(CAMPAIGN_ID), existing);
    }

    function test_FailedCreateLeavesCampaignIdAvailable() external {
        vm.expectRevert(PawfundCampaign.InvalidFundraiser.selector);

        vm.prank(owner);
        factory.createCampaign(CAMPAIGN_ID, address(0), GOAL_AMOUNT, END_AT);

        assertEq(factory.campaignAddresses(CAMPAIGN_ID), address(0));

        vm.prank(owner);
        address campaignAddress = factory.createCampaign(CAMPAIGN_ID, fundraiser, GOAL_AMOUNT, END_AT);

        assertEq(factory.campaignAddresses(CAMPAIGN_ID), campaignAddress);
    }

    function test_RevertWhen_CampaignIdIsZero() external {
        vm.expectRevert(PawfundFactory.InvalidCampaignId.selector);

        vm.prank(owner);
        factory.createCampaign(bytes16(0), fundraiser, GOAL_AMOUNT, END_AT);
    }

    function test_RevertWhen_NonOwnerCreatesCampaign() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));

        vm.prank(stranger);
        factory.createCampaign(CAMPAIGN_ID, fundraiser, GOAL_AMOUNT, END_AT);
    }

    function test_RevertWhen_FundraiserIsZero() external {
        vm.expectRevert(PawfundCampaign.InvalidFundraiser.selector);

        vm.prank(owner);
        factory.createCampaign(CAMPAIGN_ID, address(0), GOAL_AMOUNT, END_AT);
    }

    function test_RevertWhen_GoalAmountIsZero() external {
        vm.expectRevert(PawfundCampaign.InvalidGoalAmount.selector);

        vm.prank(owner);
        factory.createCampaign(CAMPAIGN_ID, fundraiser, 0, END_AT);
    }

    function test_RevertWhen_EndAtIsNotInFuture() external {
        vm.expectRevert(abi.encodeWithSelector(PawfundCampaign.InvalidEndAt.selector, START_AT));

        vm.prank(owner);
        factory.createCampaign(CAMPAIGN_ID, fundraiser, GOAL_AMOUNT, START_AT);
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
