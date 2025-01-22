// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ConstructorParams, FraxlendPairDeployer} from "../src/contracts/FraxlendPairDeployer.sol";
import {FraxlendPairRegistry} from "../src/contracts/FraxlendPairRegistry.sol";
import {FraxlendWhitelist} from "../src/contracts/FraxlendWhitelist.sol";

contract DeployCore is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployer);

        // address borrowAsset = vm.envAddress("BORROW_ASSET");
        address[] memory _noopAddrAry;

        FraxlendWhitelist whitelist = new FraxlendWhitelist();
        FraxlendPairRegistry registry = new FraxlendPairRegistry(deployer, _noopAddrAry);
        FraxlendPairDeployer frDeployer = new FraxlendPairDeployer(
            ConstructorParams({
                circuitBreaker: deployer,
                comptroller: deployer,
                timelock: deployer,
                fraxlendWhitelist: address(whitelist),
                fraxlendPairRegistry: address(registry)
            })
        );

        address[] memory _am = new address[](1);
        _am[0] = address(frDeployer);
        registry.setDeployers(_am, true);

        console2.log("FraxlendWhitelist:", address(whitelist));
        console2.log("FraxlendPairRegistry:", address(registry));
        console2.log("FraxlendPairDeployer:", address(frDeployer));

        vm.stopBroadcast();
    }
}
