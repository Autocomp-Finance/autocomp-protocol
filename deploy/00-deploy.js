// deploy/00_deploy_my_contract.js
const { pool } = require("../scripts/ACFI/data/ubeswap_celo_pools");

const pair = pool["ubeswap-celo-sol-celo"];
// console.log("pair", pair);

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log("deployer", deployer);
  await deploy("AutocompVaultV1", {
    from: deployer,
    args: [pair.strategyAddr, pair.tokenName, pair.symbol, pair.delay],
    log: true,
  });
};
module.exports.tags = ["AutocompVaultV1"];
