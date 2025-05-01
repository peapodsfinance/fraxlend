// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {VariableInterestRate} from "../src/contracts/VariableInterestRate.sol";

contract DeployVIRScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(vm.addr(deployerPrivateKey));

        // Example: https://etherscan.io/address/0x18500cB1f2fE7a40eBdA393383A0B8548a31F261
        // [0.5 0.2@.875 5-10k] 2 days (.75-.85)
        VariableInterestRate vir = new VariableInterestRate(
            "[0.5 0.2@.875 5-10k] 2 days (.75-.85)", // name
            87500, // _vertexUtilization: 0.875 * 1e5
            200000000000000000, // _vertexRatePercentOfDelta
            75000, // _minUtil: 0.75 * 1e5
            85000, // _maxUtil: 0.85 * 1e5
            158247046, // _zeroUtilizationRate: ~0.158
            1582470460, // _minFullUtilizationRate: ~1.582
            3164940920000, // _maxFullUtilizationRate: ~3164.94
            172800 // _rateHalfLife
        );

        console2.log("VariableInterestRate deployed at:", address(vir));

        vm.stopBroadcast();
    }
}
