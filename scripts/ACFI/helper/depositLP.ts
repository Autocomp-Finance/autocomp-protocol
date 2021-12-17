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

  const { BigNumber } = ethers;

  const transactionOptions = {
    gasLimit: 9900000,
  };

  const autocompVaultV1 = await ethers.getContractAt(
    "AutocompVaultV1",
    pair.AutocompVaultV1Addr
  );

  const ULP = await ethers.getContractAt("Token", pair.want);

  // const amount = BigNumber.from(10).pow(18).div(2);

  const LpBalance = await ULP.balanceOf(deployerAddress);
  console.log("LpBalance", ethers.utils.formatEther(LpBalance));

  // await ULP.connect(deployer).approve(pair.AutocompVaultV1Addr, LpBalance);
  // await autocompVaultV1.connect(deployer).deposit(LpBalance);

  // await autocompVaultV1.connect(deployer).withdrawAll();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
