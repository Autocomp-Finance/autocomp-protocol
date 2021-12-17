const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StrategyStakingSingleRewardLP", () => {
  let strategy;
  let newStrategy;
  let ULP;
  let BCBToken;
  let deployer;
  let deployerAddress;
  let deployer_;
  let autocompVaultV1;

  before("setup", async () => {
    const [deployer] = await ethers.getSigners();
    deployer_ = deployer;

    deployerAddress = await deployer.getAddress();
    console.log("deployerAddress", deployerAddress);

    BCBToken = await ethers.getContractAt(
      "Token",
      "0xc6e9b76EC10dc7dA6F1BB4d08f3BEC1fd1299cf4"
    );

    ULP = await ethers.getContractAt(
      "Token",
      "0xC3AE01De84305eac19CB14EF9b4d2f12753AD2b3"
    );

    strategy = await ethers.getContractAt(
      "StrategyStakingSingleRewardLP",
      "0x39a5895f60dE8CE5BbA9A981c01728a7BB557307"
    );

    newStrategy = await ethers.getContractAt(
      "StrategyStakingSingleRewardLP",
      "0xB3da476A1C73CBc612e99A8F2ABa148Eb1d9e643"
    );

    autocompVaultV1 = await ethers.getContractAt(
      "TestVault",
      "0x0d2f3b46C58990B612A6Ff61144B8E15F90Ef792"
    );

    await strategy.setVault(autocompVaultV1.address);
  });

  afterEach("cleanup", async () => {
    // await ganache.revert();
    // await ganache.startMine();
  });

  // positive tests
  it.only("should have variable set correctly", async () => {
    const supply = await autocompVaultV1.balance();
    console.log("supply", supply.toString());
    const vault = await strategy.vault();
    const strategyAddr = await autocompVaultV1.strategy();
    const want = await autocompVaultV1.want();
    expect(vault).to.equal("0x0d2f3b46C58990B612A6Ff61144B8E15F90Ef792");
    expect(strategyAddr).to.equal("0xB3da476A1C73CBc612e99A8F2ABa148Eb1d9e643");
    expect(want).to.equal("0xC3AE01De84305eac19CB14EF9b4d2f12753AD2b3");
  });

  it("should deposit", async () => {
    const beforeBal = await autocompVaultV1.balance();
    await ULP.connect(deployer_).approve(autocompVaultV1.address, 100);
    await (await autocompVaultV1.connect(deployer_).deposit(100)).wait();
    const afterBal = await autocompVaultV1.balance();
    expect(afterBal - beforeBal).to.equal(100);
  });

  it("should withdraw", async () => {
    const beforeBal = await autocompVaultV1.balance();
    await ULP.connect(deployer_).approve(autocompVaultV1.address, 100);
    await (await autocompVaultV1.connect(deployer_).deposit(100)).wait();
    const afterBal = await autocompVaultV1.balance();
    expect(afterBal - beforeBal).to.equal(100);

    // then withdraw the 100
    await (await autocompVaultV1.connect(deployer_).withdraw(100)).wait();
    const afterWithdraw = await autocompVaultV1.balance();
    expect(afterWithdraw.toNumber()).to.lessThanOrEqual(beforeBal.toNumber());
  });

  it("should upgradeStrat", async () => {
    await (await newStrategy.setVault(autocompVaultV1.address)).wait();
    const oldStatBal = await autocompVaultV1.balance();
    await (
      await autocompVaultV1
        .connect(deployer_)
        .proposeStrat(newStrategy.address)
    ).wait();

    await (await autocompVaultV1.connect(deployer_).upgradeStrat()).wait();

    const afterUpgaradeOldStat = await strategy.balanceOf();
    const afterUpgaradeNewStat = await newStrategy.balanceOf();
    console.log(
      "beforeHarvest",
      oldStatBal.toString(),
      afterUpgaradeOldStat.toString()
    );
    console.log("afterUpgaradeNewStat", afterUpgaradeNewStat.toString());

    expect(oldStatBal.toNumber()).to.equal(afterUpgaradeNewStat.toNumber());
    expect(afterUpgaradeOldStat.toNumber()).to.equal(0);
  });
});
