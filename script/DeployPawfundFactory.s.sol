// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Script} from "forge-std-1.16.2/src/Script.sol";
import {console2} from "forge-std-1.16.2/src/console2.sol";
import {IERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/IERC20.sol";

import {PawfundFactory} from "../src/PawfundFactory.sol";

contract DeployPawfundFactory is Script {
    error UnsupportedChain(uint256 chainId);

    uint256 internal constant BASE_MAINNET_CHAIN_ID = 8453;
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

    address internal constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant BASE_SEPOLIA_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    function run() external returns (PawfundFactory factory) {
        address initialOwner = vm.envAddress("PAWFUND_INITIAL_OWNER");
        address usdc = usdcForChain(block.chainid);

        vm.startBroadcast();
        factory = new PawfundFactory(initialOwner, IERC20(usdc));
        vm.stopBroadcast();

        console2.log("PawfundFactory:", address(factory));
        console2.log("Initial owner:", initialOwner);
        console2.log("USDC:", usdc);
        console2.log("Chain ID:", block.chainid);
    }

    function usdcForChain(uint256 chainId) public pure returns (address) {
        if (chainId == BASE_MAINNET_CHAIN_ID) {
            return BASE_MAINNET_USDC;
        }
        if (chainId == BASE_SEPOLIA_CHAIN_ID) {
            return BASE_SEPOLIA_USDC;
        }

        revert UnsupportedChain(chainId);
    }
}
