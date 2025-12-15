// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {FraxlendPair} from "../src/FraxlendPair.sol";
import {VaultAccount, VaultAccountingLibrary} from "../src/libraries/VaultAccount.sol";

interface IIndexManager {
    struct IIndexAndStatus {
        address index; // aka pod
        address creator;
        bool verified; // whether it's a safe pod as confirmed by the protocol team
        bool selfLending; // if it's an LVF pod, whether it's self-lending or not
        bool makePublic; // whether it should show in the UI or not
    }

    function allIndexes() external view returns (IIndexAndStatus[] memory);
}

interface ILeverageManager {
    function lendingPairs(address _pod) external view returns (address _lendingPair);
}

contract WithdrawFees is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(vm.addr(deployerPrivateKey));

        address indexManager = vm.envAddress("INDEX_MANAGER");
        address leverageManager = vm.envAddress("LVF");
        address treasury = 0x88eaFE23769a4FC2bBF52E77767C3693e6acFbD5;

        IIndexManager.IIndexAndStatus[] memory _pods = IIndexManager(indexManager).allIndexes();
        for (uint256 _i; _i < _pods.length; _i++) {
            address _pod = _pods[_i].index;
            address _pair = ILeverageManager(leverageManager).lendingPairs(_pod);
            if (_pair == address(0)) {
                continue;
            }

            address asset = FraxlendPair(_pair).asset();
            uint256 shares = FraxlendPair(_pair).balanceOf(_pair);
            if (shares == 0) {
                continue;
            }
            uint256 assetsFromShares = FraxlendPair(_pair).convertToAssets(shares);
            if (IERC20Metadata(asset).balanceOf(_pair) < assetsFromShares) {
                continue;
            }
            console2.log("treasury bal before", asset, IERC20Metadata(asset).balanceOf(treasury));
            FraxlendPair(_pair).withdrawFees(uint128(shares), treasury);
            console2.log("treasury bal after", asset, IERC20Metadata(asset).balanceOf(treasury));
        }

        vm.stopBroadcast();
    }
}
