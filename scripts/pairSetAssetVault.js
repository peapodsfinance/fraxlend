const assert = require('assert');
const { Counter } = require('./_utils');

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log('Deploying contracts with the account:', deployer.address);

  console.log('Account balance:', (await deployer.getBalance()).toString());

  const nonce = await deployer.getTransactionCount();
  const nonceCounter = Counter(nonce - 1);

  const pairCa = process.env.PAIR;
  const vaultCa = process.env.VAULT;
  assert(pairCa && vaultCa, 'PAIR & VAULT present');

  const pair = await ethers.getContractAt('FraxlendPair', pairCa);
  console.log(`Timelock address: ${await pair.timelockAddress()}`);

  await pair.setExternalAssetVault(vaultCa, {
    nonce: nonceCounter.increment(),
  });
  console.log('Script complete!');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
