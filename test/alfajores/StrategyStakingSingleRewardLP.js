const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StrategyStakingSingleRewardLP", () => {
  let strategy;
  let ULP;
  let BCBToken;
  let deployer;
  let deployerAddress;
  let deployer_;

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
      "0xB3da476A1C73CBc612e99A8F2ABa148Eb1d9e643"
    );
  });

  afterEach("cleanup", async () => {
    // await ganache.revert();
    // await ganache.startMine();
  });

  // positive tests
  it("should have variable set correctly", async () => {
    const supply = await strategy.balanceOfPool();
    console.log("supply", supply.toString());

    const vault = await strategy.vault();
    const want = await strategy.want();
    const lpToken0 = await strategy.lpToken0();
    const lpToken1 = await strategy.lpToken1();
    expect(vault).to.equal("0x0d2f3b46C58990B612A6Ff61144B8E15F90Ef792");
    expect(want).to.equal("0xC3AE01De84305eac19CB14EF9b4d2f12753AD2b3");
    expect(lpToken0).to.equal("0xaE762db446B805daBEda89992cBC0a6A3A59fb68");
    expect(lpToken1).to.equal("0xc6e9b76EC10dc7dA6F1BB4d08f3BEC1fd1299cf4");
  });

  it("should deposit", async () => {
    const beforeBal = await strategy.balanceOf();
    await ULP.connect(deployer_).approve(strategy.address, 100);
    await ULP.connect(deployer_).transfer(strategy.address, 100);
    await strategy.connect(deployer_).deposit();
    const afterBal = await strategy.balanceOf();
    expect(afterBal - beforeBal).to.equal(100);
  });

  it("should withdraw", async () => {
    const beforeBal = await strategy.balanceOf();
    await ULP.connect(deployer_).approve(strategy.address, 100);
    await ULP.connect(deployer_).transfer(strategy.address, 100);
    await (await strategy.connect(deployer_).deposit()).wait();
    const afterBal = await strategy.balanceOf();
    expect(afterBal - beforeBal).to.equal(100);

    // then withdraw the 100
    // set the vault add to deployer
    const vault = await strategy.vault();
    await strategy.setVault(deployerAddress); // for testing purpose only
    await (await strategy.connect(deployer_).withdraw(100)).wait();
    const afterWithdraw = await strategy.balanceOf();
    await (await strategy.setVault(vault)).wait(); // set it back
    expect(afterWithdraw).to.equal(beforeBal);
    it.done();
  });

  it.only("should harvest", async () => {
    const beforeHarvest = await strategy.balanceOf();
    await (await strategy.connect(deployer_).harvest()).wait();
    const afterHarvest = await strategy.balanceOf();
    console.log(
      "beforeHarvest",
      beforeHarvest.toString(),
      afterHarvest.toString()
    );
    expect(beforeHarvest).to.lessThanOrEqual(afterHarvest);
    it.done();
  });
});
