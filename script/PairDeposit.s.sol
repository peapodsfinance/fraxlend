// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FraxlendPair} from "../src/contracts/FraxlendPair.sol";

contract PairDepositScript is Script {
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function setUp() public {}

    function run() public {
        // Get the pair address from environment variable
        address pair = vm.envAddress("PAIR");
        require(pair != address(0), "PAIR address not set");

        vm.startBroadcast();

        // Approve USDC spending
        IERC20 usdc = IERC20(USDC);
        uint256 maxApproval = type(uint96).max;
        usdc.approve(pair, maxApproval);
        console2.log("USDC approved for pair:", pair);

        // Get USDC decimals and calculate deposit amount (1 USDC)
        uint8 decimals = IERC20Metadata(USDC).decimals();
        uint256 depositAmount = 1 * 10**decimals;

        // Perform deposit
        FraxlendPair(pair).deposit(
            depositAmount,
            msg.sender
        );
        console2.log("Deposit complete! Amount:", depositAmount);

        vm.stopBroadcast();
    }
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}
