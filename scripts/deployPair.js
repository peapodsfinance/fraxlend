const hre = require('hardhat');
// const assert = require('assert');
// const BigNumber = require('bignumber.js');

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log('Deploying contracts with the account:', deployer.address);

  console.log('Account balance:', (await deployer.getBalance()).toString());

  const FraxlendPair = await hre.ethers.getContractFactory('FraxlendPair');

  const abi = hre.ethers.utils.defaultAbiCoder;
  // address _asset,
  // address _collateral,
  // address _oracle,
  // uint32 _maxOracleDeviation,
  // address _rateContract,
  // uint64 _fullUtilizationRate,
  // uint256 _maxLTV,
  // uint256 _liquidationFee,
  // uint256 _protocolLiquidationFee
  const configData = abi.encode(
    ['address', 'address', 'address', 'uint32', 'address', 'uint64', 'uint256', 'uint256', 'uint256'],
    [
      '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // Arbitrum USDC
      // '0x21a4F940E58271a733ecF2A262fDf62cd10a1132', // Arbitrum apPEASUSDC
      // '0x83d3933364dd311055009614B68698315C7Ac2de', // Arbitrum test aspPEASUSDC (zAPP)
      '0x3F276c52A416dBb5Ec1554d9e9Ff6E65cFB7be2b', // self lending Arbitrum test aspPEASUSDC (zAPP, salt: 0)
      // '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419', // mainnet
      '0x0aeD34a4D48F7a55c9E029dCD63a2429b523cF26', // Arbitrum apPEASUSDC
      '5000',
      // '0x18500cB1f2fE7a40eBdA393383A0B8548a31F261', // mainnet
      '0x31CA9b1779e0BFAf3F5005ac4Bf2Bd74DCB8c8cE', // Arbitrum
      '90000',
      // '50000', // 50% LTV
      '0', // noop maxLTV, allow any LTV
      '10000',
      '1000',
    ],
  );

  // address _circuitBreakerAddress,
  // address _comptrollerAddress,
  // address _timelockAddress
  const immutables = abi.encode(
    ['address', 'address', 'address'],
    [
      '0x93beE8C5f71c256F3eaE8Cdc33aA1f57711E6F38',
      '0x93beE8C5f71c256F3eaE8Cdc33aA1f57711E6F38',
      '0x93beE8C5f71c256F3eaE8Cdc33aA1f57711E6F38',
    ],
  );

  // string memory _nameOfContract,
  // string memory _symbolOfContract,
  // uint8 _decimalsOfContract
  const customConfigData = abi.encode(['string memory', 'string memory', 'uint8'], ['Test Thing', 'TSTTHNG', '18']);

  const newPair = await FraxlendPair.deploy(configData, immutables, customConfigData);
  console.log('newPair address:', newPair.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
