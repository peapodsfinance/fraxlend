const hre = require('hardhat');
// const assert = require('assert');
// const BigNumber = require('bignumber.js');

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log('Deploying contracts with the account:', deployer.address);

  console.log('Account balance:', (await deployer.getBalance()).toString());

  const VariableInterestRate = await hre.ethers.getContractFactory('VariableInterestRate');

  // https://etherscan.io/address/0x18500cB1f2fE7a40eBdA393383A0B8548a31F261#code
  const vir = await VariableInterestRate.deploy(
    '[0.5 0.2@.875 5-10k] 2 days (.75-.85)',
    '87500',
    '200000000000000000',
    '75000',
    '85000',
    '158247046',
    '1582470460',
    '3164940920000',
    '172800',
  );
  console.log('vir address:', vir.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
