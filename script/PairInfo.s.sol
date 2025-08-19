// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {FraxlendPair} from "../src/contracts/FraxlendPair.sol";
import {VaultAccount, VaultAccountingLibrary} from "../src/contracts/libraries/VaultAccount.sol";

contract PairInfo is Script {
    using VaultAccountingLibrary for VaultAccount;

    function setUp() public {}

    function run() public {
        address pair = vm.envAddress("PAIR");

        address rateContract = address(FraxlendPair(pair).rateContract());
        address _externalAssetVault = address(FraxlendPair(pair).externalAssetVault());
        uint256 _protLiqFee = FraxlendPair(pair).protocolLiquidationFee();
        (, uint32 feeToProtocolRate,, uint64 ratePerSec, uint64 fullUtilizationRate) =
            FraxlendPair(pair).currentRateInfo();
        (address oracle,,, uint256 lowExchangeRate, uint256 highExchangeRate) = FraxlendPair(pair).exchangeRateInfo();

        (
            ,
            ,
            ,
            FraxlendPair.CurrentRateInfo memory _newCurrentRateInfo,
            VaultAccount memory _totalAsset,
            VaultAccount memory _totalBorrow
        ) = FraxlendPair(pair).previewAddInterest();
        uint256 _totalAssetsAvailable = _totalAsset.totalAmount(_externalAssetVault);
        uint256 _utilizationRate = _totalAssetsAvailable == 0
            ? 0
            : (FraxlendPair(pair).UTIL_PREC() * _totalBorrow.amount) / _totalAssetsAvailable;

        // Log the results
        console2.log("Owner:", FraxlendPair(pair).owner());
        console2.log("Metavault:", _externalAssetVault);
        console2.log("Rate contract:", address(FraxlendPair(pair).rateContract()));
        console2.log("protocolLiquidationFee:", _protLiqFee);
        console2.log("currentRateInfo.feeToProtocolRate:", feeToProtocolRate);
        console2.log("currentRateInfo.ratePerSec:", ratePerSec);
        console2.log("currentRateInfo.fullUtilizationRate:", fullUtilizationRate);
        console2.log("currentRateInfo.ratePerYear6:", uint256(ratePerSec) * 60 * 60 * 24 * 365 / 10 ** 12);
        console2.log("_newCurrentRateInfo.ratePerSec:", _newCurrentRateInfo.ratePerSec);
        console2.log(
            "_newCurrentRateInfo.ratePerYear6:", uint256(_newCurrentRateInfo.ratePerSec) * 60 * 60 * 24 * 365 / 10 ** 12
        );
        console2.log("Oracle:", oracle);
        console2.log("lowExchangeRate:", lowExchangeRate);
        console2.log("highExchangeRate:", highExchangeRate);
        console2.log("_totalBorrow.amount", _totalBorrow.amount);
        console2.log("_totalAssetsAvailable", _totalAssetsAvailable);
        console2.log("totalAssets", FraxlendPair(pair).totalAssets());
        console2.log("utilization", _utilizationRate);
    }
}
