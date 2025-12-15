// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ConstructorParams, FraxlendPairDeployer} from "../src/FraxlendPairDeployer.sol";
import {FraxlendPairRegistry} from "../src/FraxlendPairRegistry.sol";
import {FraxlendWhitelist} from "../src/FraxlendWhitelist.sol";
import {FraxlendPair} from "../src/FraxlendPair.sol";

contract SetDeployerNewOwner is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address newOwner = vm.envAddress("OWNER");

        vm.startBroadcast(deployer);

        FraxlendPairDeployer frDeployer = FraxlendPairDeployer(vm.envAddress("DEPLOYER"));
        frDeployer.setComptroller(newOwner);
        frDeployer.setCircuitBreaker(newOwner);
        frDeployer.setTimelock(newOwner);
        frDeployer.transferOwnership(newOwner);

        console2.log("Success!");

        vm.stopBroadcast();
    }
}
