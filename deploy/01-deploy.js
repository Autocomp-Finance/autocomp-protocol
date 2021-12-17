const { pool, address } = require("../scripts/ACFI/data/ubeswap_celo_pools");

const pair = pool["ubeswap-celo-sol-celo"];

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log("deployer", deployer);

  await deploy("StrategyStakingDoubleRewardLP", {
    from: deployer,
    gasLimit: 19999999,
    args: [
      pair.want,
      pair.chef,
      {
        keeper: address.keeperAddress,
        strategist: address.strategistAddress,
        unirouter: address.unirouter,
        vault: deployer, // will change after vault is depolyed
        autocompFeeRecipient: address.autocompFeeRecipient,
        harvester: address.harvesterAddress,
      },
      pair.outputToNativeRoute,
      pair.outputToLp0Route,
      pair.outputToLp1Route,
      pair.output2ToOutput,
    ],
    log: true,
  });
};
module.exports.tags = ["StrategyStakingDoubleRewardLP"];
