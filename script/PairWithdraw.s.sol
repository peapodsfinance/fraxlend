// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FraxlendPair} from "../src/contracts/FraxlendPair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PairWithdrawScript is Script {
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function setUp() public {}

    function run() public {
        // Get the pair address from environment variable
        address pair = vm.envAddress("PAIR");
        require(pair != address(0), "PAIR address not set");

        vm.startBroadcast();

        // Get USDC decimals and calculate withdraw amount (0.01 USDC)
        uint8 decimals = IERC20Metadata(USDC).decimals();
        uint256 withdrawAmount = (1 * 10 ** decimals) / 100; // 0.01 USDC

        // Perform withdrawal
        FraxlendPair(pair).withdraw(
            withdrawAmount,
            msg.sender, // receiver
            msg.sender // owner
        );
        console2.log("Withdrawal complete! Amount:", withdrawAmount);

        vm.stopBroadcast();
    }
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}
