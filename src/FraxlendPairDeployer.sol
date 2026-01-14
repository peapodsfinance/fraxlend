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
// ====================== FraxlendPairDeployer ========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author
// Drake Evans: https://github.com/DrakeEvans

// Reviewers
// Dennis: https://github.com/denett
// Sam Kazemian: https://github.com/samkazemian
// Travis Moore: https://github.com/FortisFortuna
// Jack Corddry: https://github.com/corddry
// Rich Gee: https://github.com/zer0blockchain

// ====================================================================

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SSTORE2} from "@rari-capital/solmate/src/utils/SSTORE2.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";
import {IFraxlendWhitelist} from "./interfaces/IFraxlendWhitelist.sol";
import {IFraxlendPair} from "./interfaces/IFraxlendPair.sol";
import {IFraxlendPairRegistry} from "./interfaces/IFraxlendPairRegistry.sol";
import {SafeERC20} from "./libraries/SafeERC20.sol";

// solhint-disable no-inline-assembly

struct ConstructorParams {
    address circuitBreaker;
    address comptroller;
    address timelock;
    address fraxlendWhitelist;
    address fraxlendPairRegistry;
}

/// @title FraxlendPairDeployer
/// @author Drake Evans (Frax Finance) https://github.com/drakeevans
/// @notice Deploys and initializes new FraxlendPairs
/// @dev Uses create2 to deploy the pairs, logs an event, and records a list of all deployed pairs
contract FraxlendPairDeployer is Ownable {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    // Storage
    address public contractAddress1;
    address public contractAddress2;

    // Admin contracts
    address public circuitBreakerAddress;
    address public comptrollerAddress;
    address public timelockAddress;
    address public fraxlendPairRegistryAddress;
    address public fraxlendWhitelistAddress;

    // Default deposit amount for new pairs
    uint256 public defaultDepositAmt;

    /// @notice Amount of asset to seed into each pair on creation
    uint256 amountToSeed;

    /// @notice Emits when a new pair is deployed
    /// @notice The ```LogDeploy``` event is emitted when a new Pair is deployed
    /// @param address_ The address of the pair
    /// @param asset The address of the Asset Token contract
    /// @param collateral The address of the Collateral Token contract
    /// @param name The name of the Pair
    /// @param configData The config data of the Pair
    /// @param immutables The immutables of the Pair
    /// @param customConfigData The custom config data of the Pair
    event LogDeploy(
        address indexed address_,
        address indexed asset,
        address indexed collateral,
        string name,
        bytes configData,
        bytes immutables,
        bytes customConfigData
    );

    /// @notice List of the names of all deployed Pairs
    address[] public deployedPairsArray;

    constructor(ConstructorParams memory _params) Ownable(msg.sender) {
        circuitBreakerAddress = _params.circuitBreaker;
        comptrollerAddress = _params.comptroller;
        timelockAddress = _params.timelock;
        fraxlendWhitelistAddress = _params.fraxlendWhitelist;
        fraxlendPairRegistryAddress = _params.fraxlendPairRegistry;
    }

    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (5, 0, 0);
    }

    // ============================================================================================
    // Functions: View Functions
    // ============================================================================================

    /// @notice The ```deployedPairsLength``` function returns the length of the deployedPairsArray
    /// @return length of array
    function deployedPairsLength() external view returns (uint256) {
        return deployedPairsArray.length;
    }

    /// @notice The ```getAllPairAddresses``` function returns all pair addresses in deployedPairsArray
    /// @return _deployedPairs memory All deployed pair addresses
    function getAllPairAddresses() external view returns (address[] memory _deployedPairs) {
        _deployedPairs = deployedPairsArray;
    }

    function getNextNameSymbol(address _asset) public view returns (string memory _name, string memory _symbol) {
        return getNameSymbolAtOffset(_asset, 0);
    }

    /// @notice Get name/symbol for a FraxlendPair with a specific offset from current registry length
    /// @dev Used for predicting names when multiple pairs will be deployed in sequence
    /// @param _asset The asset token address
    /// @param _offset Number of pairs that will be deployed before this one (0 = next, 1 = one after next, etc.)
    /// @return _name The name for the pair
    /// @return _symbol The symbol for the pair
    function getNameSymbolAtOffset(address _asset, uint256 _offset)
        public
        view
        returns (string memory _name, string memory _symbol)
    {
        uint256 _length = IFraxlendPairRegistry(fraxlendPairRegistryAddress).deployedPairsLength();
        uint256 _pairNumber = _length + 1 + _offset;
        _name = string(
            abi.encodePacked("Peapods Interest Bearing ", IERC20(_asset).safeSymbol(), " - ", _pairNumber.toString())
        );
        _symbol = string(abi.encodePacked("pf", IERC20(_asset).safeSymbol(), "-", _pairNumber.toString()));
    }

    /// @notice Compute the CREATE2 address for a FraxlendPair before deployment
    /// @dev The salt AND bytecode are computed WITHOUT collateral to allow address prediction in circular dependency scenarios
    ///      (e.g., when PodLPToken needs to know FraxlendPair address, but FraxlendPair needs PodLPToken as collateral)
    ///      Collateral is set via setCollateral() after deployment.
    /// @param _configData The config data (same as deploy function) - collateral field is ignored
    /// @param _name The name for the pair (use getNextNameSymbol to compute)
    /// @param _symbol The symbol for the pair (use getNextNameSymbol to compute)
    /// @return _pairAddress The predicted address
    function computeAddress(bytes memory _configData, string memory _name, string memory _symbol)
        external
        view
        returns (address _pairAddress)
    {
        // Extract only the asset address (first 32 bytes of _configData)
        address _asset;
        assembly {
            _asset := mload(add(_configData, 32))
        }

        bytes memory _immutables = abi.encode(circuitBreakerAddress, comptrollerAddress, timelockAddress);
        bytes memory _customConfigData = abi.encode(_name, _symbol, IERC20(_asset).safeDecimals());

        // Compute salt WITHOUT collateral - uses only asset, immutables, and custom config
        bytes32 salt = _computeSaltWithoutCollateral(_asset, _immutables, _customConfigData);

        // Create config data with zeroed collateral for bytecode
        // Copy _configData and zero out the collateral address (bytes 32-64)
        bytes memory _zeroedConfigData = new bytes(_configData.length);
        for (uint256 i = 0; i < _configData.length; i++) {
            _zeroedConfigData[i] = _configData[i];
        }
        assembly {
            // Zero out bytes 32-64 (collateral address) - offset is 32 (length) + 32 (first slot) = 64
            mstore(add(_zeroedConfigData, 64), 0)
        }

        // Get creation code
        bytes memory _creationCode = SSTORE2.read(contractAddress1);
        if (contractAddress2 != address(0)) {
            _creationCode = BytesLib.concat(_creationCode, SSTORE2.read(contractAddress2));
        }

        // Get bytecode with zeroed collateral
        bytes memory bytecode =
            abi.encodePacked(_creationCode, abi.encode(_zeroedConfigData, _immutables, _customConfigData));

        // Compute CREATE2 address
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));
        _pairAddress = address(uint160(uint256(hash)));
    }

    /// @notice Compute a salt that doesn't include collateral address
    /// @dev This enables address prediction for circular dependency scenarios
    /// @param _asset The asset token address
    /// @param _immutables The immutables data
    /// @param _customConfigData The custom config data (name, symbol, decimals)
    /// @return The computed salt
    function _computeSaltWithoutCollateral(address _asset, bytes memory _immutables, bytes memory _customConfigData)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_asset, _immutables, _customConfigData));
    }

    // ============================================================================================
    // Functions: Setters
    // ============================================================================================

    /// @notice The ```setCreationCode``` function sets the bytecode for the fraxlendPair
    /// @dev splits the data if necessary to accommodate creation code that is slightly larger than 24kb
    /// @param _creationCode The creationCode for the Fraxlend Pair
    function setCreationCode(bytes calldata _creationCode) external onlyOwner {
        bytes memory _firstHalf = BytesLib.slice(_creationCode, 0, 13_000);
        contractAddress1 = SSTORE2.write(_firstHalf);
        if (_creationCode.length > 13_000) {
            bytes memory _secondHalf = BytesLib.slice(_creationCode, 13_000, _creationCode.length - 13_000);
            contractAddress2 = SSTORE2.write(_secondHalf);
        } else {
            contractAddress2 = address(0);
        }
    }

    function setDefaultDepositAmt(uint256 _amount) external onlyOwner {
        defaultDepositAmt = _amount;
    }

    /// @notice The ```SetTimelock``` event is emitted when the timelockAddress is set
    /// @param oldAddress The original address
    /// @param newAddress The new address
    event SetTimelock(address oldAddress, address newAddress);

    /// @notice The ```setTimelock``` function sets the timelockAddress
    /// @param _newAddress the new time lock address
    function setTimelock(address _newAddress) external onlyOwner {
        emit SetTimelock(timelockAddress, _newAddress);
        timelockAddress = _newAddress;
    }

    /// @notice The ```SetRegistry``` event is emitted when the fraxlendPairRegistryAddress is set
    /// @param oldAddress The old address
    /// @param newAddress The new address
    event SetRegistry(address oldAddress, address newAddress);

    /// @notice The ```setRegistry``` function sets the fraxlendPairRegistryAddress
    /// @param _newAddress The new address
    function setRegistry(address _newAddress) external onlyOwner {
        emit SetRegistry(fraxlendPairRegistryAddress, _newAddress);
        fraxlendPairRegistryAddress = _newAddress;
    }

    /// @notice The ```SetComptroller``` event is emitted when the comptrollerAddress is set
    /// @param oldAddress The old address
    /// @param newAddress The new address
    event SetComptroller(address oldAddress, address newAddress);

    /// @notice The ```setComptroller``` function sets the comptrollerAddress
    /// @param _newAddress The new address
    function setComptroller(address _newAddress) external onlyOwner {
        emit SetComptroller(comptrollerAddress, _newAddress);
        comptrollerAddress = _newAddress;
    }

    /// @notice The ```SetWhitelist``` event is emitted when the fraxlendWhitelistAddress is set
    /// @param oldAddress The old address
    /// @param newAddress The new address
    event SetWhitelist(address oldAddress, address newAddress);

    /// @notice The ```setWhitelist``` function sets the fraxlendWhitelistAddress
    /// @param _newAddress The new address
    function setWhitelist(address _newAddress) external onlyOwner {
        emit SetWhitelist(fraxlendWhitelistAddress, _newAddress);
        fraxlendWhitelistAddress = _newAddress;
    }

    /// @notice The ```SetCircuitBreaker``` event is emitted when the circuitBreakerAddress is set
    /// @param oldAddress The old address
    /// @param newAddress The new address
    event SetCircuitBreaker(address oldAddress, address newAddress);

    /// @notice The ```setCircuitBreaker``` function sets the circuitBreakerAddress
    /// @param _newAddress The new address
    function setCircuitBreaker(address _newAddress) external onlyOwner {
        emit SetCircuitBreaker(circuitBreakerAddress, _newAddress);
        circuitBreakerAddress = _newAddress;
    }

    /// @notice the ```SetAmountToSeed``` event is emitted when the AmountToSeed is set
    /// @param oldAmountToSeed The old amount to seed new pairs
    /// @param newAmountToSeed The new amount to seed new pairs
    event SetAmountToSeed(uint256 oldAmountToSeed, uint256 newAmountToSeed);

    /// @notice the ```setAmountToSeed``` function sets the amount of asset to seed a pair
    ///         on creation
    /// @param _amountToSeed The amount of assets to seed the newly created pairs
    function setAmountToSeed(uint256 _amountToSeed) external {
        if (!IFraxlendWhitelist(fraxlendWhitelistAddress).fraxlendDeployerWhitelist(msg.sender)) {
            revert WhitelistedDeployersOnly();
        }
        emit SetAmountToSeed(amountToSeed, _amountToSeed);
        amountToSeed = _amountToSeed;
    }

    // ============================================================================================
    // Functions: Internal Methods
    // ============================================================================================

    /// @notice The ```_deploy``` function is an internal function with deploys the pair
    /// @dev Deploys with zeroed collateral in bytecode for deterministic CREATE2 addresses, then sets collateral via setCollateral()
    /// @param _configData abi.encode(address _asset, address _collateral, address _oracle, uint32 _maxOracleDeviation, address _rateContract, uint64 _fullUtilizationRate, uint256 _maxLTV, uint256 _liquidationFee, uint256 _protocolLiquidationFee)
    /// @param _immutables abi.encode(address _circuitBreakerAddress, address _comptrollerAddress, address _timelockAddress)
    /// @param _customConfigData abi.encode(string memory _nameOfContract, string memory _symbolOfContract, uint8 _decimalsOfContract)
    /// @return _pairAddress The address to which the Pair was deployed
    function _deploy(bytes memory _configData, bytes memory _immutables, bytes memory _customConfigData)
        private
        returns (address _pairAddress)
    {
        // Extract only the asset address for salt computation (first 32 bytes of _configData)
        address _asset;
        assembly {
            _asset := mload(add(_configData, 32))
        }

        // Create config data with zeroed collateral for deterministic bytecode
        // Copy _configData and zero out the collateral address (bytes 32-64)
        bytes memory _zeroedConfigData = _configData;
        assembly {
            // Zero out bytes 32-64 (collateral address) - offset is 32 (length) + 32 (first slot) = 64
            mstore(add(_zeroedConfigData, 64), 0)
        }

        // Get creation code
        bytes memory _creationCode = SSTORE2.read(contractAddress1);
        if (contractAddress2 != address(0)) {
            _creationCode = BytesLib.concat(_creationCode, SSTORE2.read(contractAddress2));
        }

        // Get bytecode with zeroed collateral
        bytes memory bytecode =
            abi.encodePacked(_creationCode, abi.encode(_zeroedConfigData, _immutables, _customConfigData));

        // Generate salt WITHOUT collateral - enables address prediction for circular dependencies
        bytes32 salt = _computeSaltWithoutCollateral(_asset, _immutables, _customConfigData);

        /// @solidity memory-safe-assembly
        assembly {
            _pairAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        if (_pairAddress == address(0)) revert Create2Failed();

        deployedPairsArray.push(_pairAddress);

        // NOTE: Collateral must be set via setCollateral() by the timelock (usually PodLeverageFactory)
        // after deployment. The FraxlendPairDeployer cannot call it because the pair's timelock is
        // set to timelockAddress (e.g., PodLeverageFactory), not this deployer contract.

        // Set additional values for FraxlendPair
        if (defaultDepositAmt > 0) {
            address _assetAddr = IFraxlendPair(_pairAddress).asset();
            IERC20(_assetAddr).safeTransferFrom(msg.sender, address(this), defaultDepositAmt);
            IERC20(_assetAddr).approve(_pairAddress, defaultDepositAmt);
            IFraxlendPair(_pairAddress).deposit(defaultDepositAmt, msg.sender);
        }

        return _pairAddress;
    }

    // ============================================================================================
    // Functions: External Deploy Methods
    // ============================================================================================

    /// @notice The ```deploy``` function allows the deployment of a FraxlendPair with default values
    /// @param _configData abi.encode(address _asset, address _collateral, address _oracle, uint32 _maxOracleDeviation, address _rateContract, uint64 _fullUtilizationRate, uint256 _maxLTV, uint256 _maxBorrowLTV, uint256 _liquidationFee, uint256 _protocolLiquidationFee)
    /// @return _pairAddress The address to which the Pair was deployed
    function deploy(bytes memory _configData) external returns (address _pairAddress) {
        if (!IFraxlendWhitelist(fraxlendWhitelistAddress).fraxlendDeployerWhitelist(msg.sender)) {
            revert WhitelistedDeployersOnly();
        }

        (address _asset, address _collateral,,,,,,,,) = abi.decode(
            _configData, (address, address, address, uint32, address, uint64, uint256, uint256, uint256, uint256)
        );

        (string memory _name, string memory _symbol) = getNextNameSymbol(_asset);

        bytes memory _immutables = abi.encode(circuitBreakerAddress, comptrollerAddress, timelockAddress);
        bytes memory _customConfigData = abi.encode(_name, _symbol, IERC20(_asset).safeDecimals());

        _pairAddress = _deploy(_configData, _immutables, _customConfigData);

        IFraxlendPairRegistry(fraxlendPairRegistryAddress).addPair(_pairAddress);

        // Seeding is optional for testnet deployments
        if (amountToSeed > 0) {
            IERC20(_asset).safeApprove(_pairAddress, amountToSeed);
            IFraxlendPair(_pairAddress).deposit(amountToSeed, address(this));
        }

        emit LogDeploy(_pairAddress, _asset, _collateral, _name, _configData, _immutables, _customConfigData);
    }

    // ============================================================================================
    // Functions: Admin
    // ============================================================================================

    /// @notice The ```globalPause``` function calls the pause() function on a given set of pair addresses
    /// @dev Ignores reverts when calling pause()
    /// @param _addresses Addresses to attempt to pause()
    /// @return _updatedAddresses Addresses for which pause() was successful
    function globalPause(address[] memory _addresses) external returns (address[] memory _updatedAddresses) {
        if (msg.sender != circuitBreakerAddress) revert CircuitBreakerOnly();

        address _pairAddress;
        uint256 _lengthOfArray = _addresses.length;
        _updatedAddresses = new address[](_lengthOfArray);
        for (uint256 i = 0; i < _lengthOfArray;) {
            _pairAddress = _addresses[i];
            try IFraxlendPair(_pairAddress).pause() {
                _updatedAddresses[i] = _addresses[i];
            } catch {}
            unchecked {
                i = i + 1;
            }
        }
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error CircuitBreakerOnly();
    error WhitelistedDeployersOnly();
    error Create2Failed();
    error MustSeedPair();
}
