const assert = require('assert');

async function main() {
  // const [deployer] = await ethers.getSigners();

  const pairCa = process.env.PAIR;
  const user = process.env.USER;
  assert(pairCa && user, 'PAIR && USER present');

  const pair = await ethers.getContractAt('FraxlendPair', pairCa);
  console.log(`userCollateralBalance: ${await pair.userCollateralBalance(user)}`);
  console.log(`userBorrowShares: ${await pair.userBorrowShares(user)}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
