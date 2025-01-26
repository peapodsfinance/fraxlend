// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FraxlendPair} from "../src/contracts/FraxlendPair.sol";

contract PairInfo is Script {
    function setUp() public {}

    function run() public {
        address pair = vm.envAddress("PAIR");

        address rateContract = address(FraxlendPair(pair).rateContract());
        uint256 _protLiqFee = FraxlendPair(pair).protocolLiquidationFee();
        (, uint32 feeToProtocolRate,, uint64 ratePerSec,) = FraxlendPair(pair).currentRateInfo();
        (address oracle,,, uint256 lowExchangeRate, uint256 highExchangeRate) = FraxlendPair(pair).exchangeRateInfo();

        // Log the results
        console2.log("Rate contract:", rateContract);
        console2.log("protocolLiquidationFee:", _protLiqFee);
        console2.log("currentRateInfo.feeToProtocolRate:", feeToProtocolRate);
        console2.log("currentRateInfo.ratePerSec:", ratePerSec);
        console2.log("Oracle:", oracle);
        console2.log("lowExchangeRate:", lowExchangeRate);
        console2.log("highExchangeRate:", highExchangeRate);
    }
}
