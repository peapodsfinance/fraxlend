// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FraxlendPair} from "../src/contracts/FraxlendPair.sol";
import {VaultAccount, VaultAccountingLibrary} from "../src/contracts/libraries/VaultAccount.sol";

contract SetLiquidationFees is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(vm.addr(deployerPrivateKey));

        address pair = vm.envAddress("PAIR");
        uint256 cleanLiqFee = vm.envUint("CLEAN_FEE");
        uint256 protocolLiqFee = vm.envUint("PROTOCOL_FEE");

        console2.log("timelockAddress", FraxlendPair(pair).timelockAddress());
        console2.log("cleanLiquidationFee", FraxlendPair(pair).cleanLiquidationFee());
        console2.log("dirtyLiquidationFee", FraxlendPair(pair).dirtyLiquidationFee());
        console2.log("protocolLiquidationFee", FraxlendPair(pair).protocolLiquidationFee());
        console2.log(
            "minCollateralRequiredOnDirtyLiquidation", FraxlendPair(pair).minCollateralRequiredOnDirtyLiquidation()
        );

        FraxlendPair(pair)
            .setLiquidationFees(
                cleanLiqFee,
                cleanLiqFee * 9 / 10,
                protocolLiqFee,
                FraxlendPair(pair).minCollateralRequiredOnDirtyLiquidation()
            );

        console2.log("NEW cleanLiquidationFee", FraxlendPair(pair).cleanLiquidationFee());
        console2.log("NEW dirtyLiquidationFee", FraxlendPair(pair).dirtyLiquidationFee());
        console2.log("NEW protocolLiquidationFee", FraxlendPair(pair).protocolLiquidationFee());
        console2.log(
            "NEW minCollateralRequiredOnDirtyLiquidation", FraxlendPair(pair).minCollateralRequiredOnDirtyLiquidation()
        );

        vm.stopBroadcast();
    }
}
