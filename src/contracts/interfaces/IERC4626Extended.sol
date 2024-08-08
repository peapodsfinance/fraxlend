// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IERC4626Extended is IERC4626 {
    function totalAvailableAssets() external view returns (uint256);

    function totalUsed() external view returns (uint256);

    function whitelistWithdraw(uint256 amount) external;

    function whitelistDeposit(uint256 amount) external;
}