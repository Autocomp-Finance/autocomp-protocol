import { ethers } from "hardhat";
import { pool } from "../data/ubeswap_celo_pools";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log("deployerAddress", deployerAddress);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  const pair = pool["ubeswap-celo-sol-celo"];

  const strategy = await ethers.getContractAt(
    "StrategyStakingSingleRewardLP",
    pair.strategyAddr
  );

  strategy.setVault(pair.AutocompVaultV1Addr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
