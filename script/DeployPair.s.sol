// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FraxlendPair} from "../src/contracts/FraxlendPair.sol";

contract DeployPairScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Config data parameters
        address asset = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum USDC
        address collateral = 0x3F276c52A416dBb5Ec1554d9e9Ff6E65cFB7be2b; // self lending Arbitrum test aspPEASUSDC
        address oracle = 0x0aeD34a4D48F7a55c9E029dCD63a2429b523cF26; // Arbitrum apPEASUSDC
        uint32 maxOracleDeviation = 5000;
        address rateContract = 0x31CA9b1779e0BFAf3F5005ac4Bf2Bd74DCB8c8cE; // Arbitrum
        uint64 fullUtilizationRate = 90000;
        uint256 maxLTV = 0; // noop maxLTV, allow any LTV
        uint256 liquidationFee = 10000;
        uint256 protocolLiquidationFee = 1000;

        bytes memory configData = abi.encode(
            asset,
            collateral,
            oracle,
            maxOracleDeviation,
            rateContract,
            fullUtilizationRate,
            maxLTV,
            liquidationFee,
            protocolLiquidationFee
        );

        // Immutable parameters
        address circuitBreakerAddress = 0x93beE8C5f71c256F3eaE8Cdc33aA1f57711E6F38;
        address comptrollerAddress = 0x93beE8C5f71c256F3eaE8Cdc33aA1f57711E6F38;
        address timelockAddress = 0x93beE8C5f71c256F3eaE8Cdc33aA1f57711E6F38;

        bytes memory immutables = abi.encode(circuitBreakerAddress, comptrollerAddress, timelockAddress);

        // Custom config parameters
        string memory nameOfContract = "Test Thing";
        string memory symbolOfContract = "TSTTHNG";
        uint8 decimalsOfContract = 18;

        bytes memory customConfigData = abi.encode(nameOfContract, symbolOfContract, decimalsOfContract);

        // Deploy the contract
        FraxlendPair newPair = new FraxlendPair(configData, immutables, customConfigData);

        console2.log("New FraxlendPair deployed at:", address(newPair));

        vm.stopBroadcast();
    }
}
