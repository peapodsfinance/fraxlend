// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FraxlendPair} from "../src/FraxlendPair.sol";
import {VaultAccount, VaultAccountingLibrary} from "../src/libraries/VaultAccount.sol";

contract PairLiquidateScript is Script {
    using VaultAccountingLibrary for VaultAccount;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(vm.addr(deployerPrivateKey));

        // Get the pair address from environment variable
        address pair = vm.envAddress("PAIR");
        address victim = vm.envAddress("VICTIM");

        (,,,,, VaultAccount memory borrowAccount) = FraxlendPair(pair).previewAddInterest();
        uint256 amountNeeded = borrowAccount.toAmount(FraxlendPair(pair).userBorrowShares(victim), true);
        IERC20(FraxlendPair(pair).asset()).approve(pair, amountNeeded);

        // Perform deposit
        uint256 _collForLiquidation = FraxlendPair(pair)
            .liquidate(uint128(FraxlendPair(pair).userBorrowShares(victim)), block.timestamp + 1 days, victim);
        console2.log("Liquidate complete! Amount received:", _collForLiquidation);

        vm.stopBroadcast();
    }
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}
