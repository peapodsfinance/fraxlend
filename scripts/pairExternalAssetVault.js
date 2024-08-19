const assert = require('assert');

async function main() {
  // const [deployer] = await ethers.getSigners();

  const pairCa = process.env.PAIR;
  assert(pairCa, 'PAIR present');

  const pair = await ethers.getContractAt('FraxlendPair', pairCa);
  console.log(`Vault: ${await pair.externalAssetVault()}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
