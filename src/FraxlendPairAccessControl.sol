// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ==================== FraxlendPairAccessControl =====================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author
// Drake Evans: https://github.com/DrakeEvans

// Reviewers
// Dennis: https://github.com/denett

// ====================================================================

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Timelock2Step} from "./Timelock2Step.sol";
import {FraxlendPairAccessControlErrors} from "./FraxlendPairAccessControlErrors.sol";
import {IERC4626Extended} from "./interfaces/IERC4626Extended.sol";

/// @title FraxlendPairAccessControl
/// @author Drake Evans (Frax Finance) https://github.com/drakeevans
/// @notice  An abstract contract which contains the access control logic for FraxlendPair
abstract contract FraxlendPairAccessControl is Timelock2Step, Ownable2Step, FraxlendPairAccessControlErrors {
    // Deployer
    address public immutable DEPLOYER_ADDRESS;

    // Admin contracts
    address public circuitBreakerAddress;

    // External asset vault
    IERC4626Extended public externalAssetVault;

    bool public isBorrowPaused;

    bool public isDepositPaused;

    bool public isRepayPaused;

    bool public isWithdrawPaused;

    bool public isLiquidatePaused;

    bool public isInterestPaused;

    /// @param _immutables abi.encode(address _circuitBreakerAddress, address _comptrollerAddress, address _timelockAddress)
    constructor(bytes memory _immutables) Timelock2Step() Ownable(msg.sender) {
        // Handle Immutables Configuration
        (address _circuitBreakerAddress, address _comptrollerAddress, address _timelockAddress) =
            abi.decode(_immutables, (address, address, address));
        _setTimelock(_timelockAddress);
        _transferOwnership(_comptrollerAddress);

        // Deployer contract
        DEPLOYER_ADDRESS = msg.sender;
        circuitBreakerAddress = _circuitBreakerAddress;
    }

    // ============================================================================================
    // Functions: Access Control
    // ============================================================================================

    function _requireProtocolOrOwner() internal view {
        if (
            msg.sender != circuitBreakerAddress && msg.sender != owner() && msg.sender != DEPLOYER_ADDRESS
                && msg.sender != timelockAddress
        ) {
            revert OnlyProtocolOrOwner();
        }
    }

    function _requireTimelockOrOwner() internal view {
        if (msg.sender != owner() && msg.sender != timelockAddress) {
            revert OnlyTimelockOrOwner();
        }
    }

    /// @notice The ```PauseBorrow``` event is emitted when borrow is paused or unpaused
    /// @param isPaused The new paused state
    event PauseBorrow(bool isPaused);

    function _pauseBorrow(bool _isPaused) internal {
        isBorrowPaused = _isPaused;
        emit PauseBorrow(_isPaused);
    }

    /// @notice The ```PauseDeposit``` event is emitted when deposit is paused or unpaused
    /// @param isPaused The new paused state
    event PauseDeposit(bool isPaused);

    function _pauseDeposit(bool _isPaused) internal {
        isDepositPaused = _isPaused;
        emit PauseDeposit(_isPaused);
    }

    /// @notice The ```PauseRepay``` event is emitted when repay is paused or unpaused
    /// @param isPaused The new paused state
    event PauseRepay(bool isPaused);

    function _pauseRepay(bool _isPaused) internal {
        isRepayPaused = _isPaused;
        emit PauseRepay(_isPaused);
    }

    /// @notice The ```PauseWithdraw``` event is emitted when withdraw is paused or unpaused
    /// @param isPaused The new paused state
    event PauseWithdraw(bool isPaused);

    function _pauseWithdraw(bool _isPaused) internal {
        isWithdrawPaused = _isPaused;
        emit PauseWithdraw(_isPaused);
    }

    /// @notice The ```PauseLiquidate``` event is emitted when liquidate is paused or unpaused
    /// @param isPaused The new paused state
    event PauseLiquidate(bool isPaused);

    function _pauseLiquidate(bool _isPaused) internal {
        isLiquidatePaused = _isPaused;
        emit PauseLiquidate(_isPaused);
    }

    /// @notice The ```PauseInterest``` event is emitted when interest is paused or unpaused
    /// @param isPaused The new paused state
    event PauseInterest(bool isPaused);

    function _pauseInterest(bool _isPaused) internal {
        isInterestPaused = _isPaused;
        emit PauseInterest(_isPaused);
    }

    /// @notice The ```SetExternalAssetVault``` event is emitted when the external vault account is changed
    event SetExternalAssetVault(address oldVault, address newVault);

    function _setExternalAssetVault(IERC4626Extended vault) internal {
        IERC4626Extended _oldVault = externalAssetVault;
        externalAssetVault = vault;
        emit SetExternalAssetVault(address(_oldVault), address(vault));
    }

    /// @notice The ```setExternalAssetVault``` function is called to set the external asset vault for the pair
    /// @param vault The new external asset vault
    function setExternalAssetVault(IERC4626Extended vault) external {
        _requireTimelock();
        _setExternalAssetVault(vault);
    }

    /// @notice The ```SetCircuitBreaker``` event is emitted when the circuit breaker address is set
    /// @param oldCircuitBreaker The old circuit breaker address
    /// @param newCircuitBreaker The new circuit breaker address
    event SetCircuitBreaker(address oldCircuitBreaker, address newCircuitBreaker);

    /// @notice The ```_setCircuitBreaker``` function is called to set the circuit breaker address
    /// @param _newCircuitBreaker The new circuit breaker address
    function _setCircuitBreaker(address _newCircuitBreaker) internal {
        address oldCircuitBreaker = circuitBreakerAddress;
        circuitBreakerAddress = _newCircuitBreaker;
        emit SetCircuitBreaker(oldCircuitBreaker, _newCircuitBreaker);
    }

    /// @notice The ```setCircuitBreaker``` function is called to set the circuit breaker address
    /// @param _newCircuitBreaker The new circuit breaker address
    function setCircuitBreaker(address _newCircuitBreaker) external virtual {
        _requireTimelock();
        _setCircuitBreaker(_newCircuitBreaker);
    }
}
