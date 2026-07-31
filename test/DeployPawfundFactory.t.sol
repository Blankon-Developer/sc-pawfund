// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std-1.16.2/src/Test.sol";

import {DeployPawfundFactory} from "../script/DeployPawfundFactory.s.sol";

contract DeployPawfundFactoryTest is Test {
    DeployPawfundFactory internal deployment;

    function setUp() external {
        deployment = new DeployPawfundFactory();
    }

    function test_UsesCanonicalBaseMainnetUSDC() external view {
        assertEq(deployment.usdcForChain(8453), 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    }

    function test_UsesCanonicalBaseSepoliaUSDC() external view {
        assertEq(deployment.usdcForChain(84532), 0x036CbD53842c5426634e7929541eC2318f3dCF7e);
    }

    function test_RevertWhen_ChainIsUnsupported() external {
        vm.expectRevert(abi.encodeWithSelector(DeployPawfundFactory.UnsupportedChain.selector, 1));
        deployment.usdcForChain(1);
    }
}
