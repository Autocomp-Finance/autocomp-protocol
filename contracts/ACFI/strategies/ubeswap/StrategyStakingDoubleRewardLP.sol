// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../interfaces/common/IUniswapRouterETH.sol";
import "../../interfaces/common/IUniswapV2Pair.sol";
import "../../interfaces/synthetix/IStakingRewards.sol";

import "../common/StratManager.sol";
import "../common/FeeManager.sol";
import "../common/BaseStrategyDoubleRewardLP.sol";

contract StrategyStakingDoubleRewardLP is
  StratManager,
  BaseStrategyDoubleRewardLP,
  FeeManager
{
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  bool public harvestOnDeposit;

  /**
   * @dev Event that is fired each time someone harvests the strat.
   */
  event _SafeSwap(
    uint256 amountOut,
    uint256 amountInMax,
    address[] path,
    address to,
    uint256 deadline
  );

  constructor(
    address _want,
    address _chef,
    StratMgr memory stratMgr,
    address[] memory _outputToNativeRoute,
    address[] memory _outputToLp0Route,
    address[] memory _outputToLp1Route,
    address[] memory _output2ToOutputRoute
  ) public StratManager(stratMgr) {
    want = _want;
    chef = _chef;
    // console.log("stratMgr %s ", stratMgr.vault);
    require(_outputToNativeRoute.length >= 2);
    output = _outputToNativeRoute[0];
    native = _outputToNativeRoute[_outputToNativeRoute.length - 1];
    outputToNativeRoute = _outputToNativeRoute;
    // setup lp routing
    lpToken0 = IUniswapV2Pair(want).token0();
    require(_outputToLp0Route[0] == output);
    require(_outputToLp0Route[_outputToLp0Route.length - 1] == lpToken0);
    outputToLp0Route = _outputToLp0Route;
    lpToken1 = IUniswapV2Pair(want).token1();
    require(_outputToLp1Route[0] == output);
    require(_outputToLp1Route[_outputToLp1Route.length - 1] == lpToken1);
    outputToLp1Route = _outputToLp1Route;
    // setup 2nd output
    require(_output2ToOutputRoute.length >= 2);
    output2 = _output2ToOutputRoute[0];
    require(_output2ToOutputRoute[_output2ToOutputRoute.length - 1] == output);
    output2ToOutputRoute = _output2ToOutputRoute;
    _giveAllowances();
  }

  // puts the funds to work
  function deposit() public override {
    uint256 wantBal = IERC20(want).balanceOf(address(this));

    if (wantBal > 0) {
      IStakingRewards(chef).stake(wantBal);
    }
  }

  function withdraw(uint256 _amount) external {
    require(msg.sender == vault, "!vault");

    uint256 wantBal = IERC20(want).balanceOf(address(this));

    if (wantBal < _amount) {
      IStakingRewards(chef).withdraw(_amount.sub(wantBal));

      wantBal = IERC20(want).balanceOf(address(this));
    }

    if (wantBal > _amount) {
      wantBal = _amount;
    }

    if (tx.origin == owner() || paused()) {
      IERC20(want).safeTransfer(vault, wantBal);
    } else {
      uint256 withdrawalFeeAmount = wantBal.mul(withdrawalFee).div(
        WITHDRAWAL_MAX
      );
      IERC20(want).safeTransfer(vault, wantBal.sub(withdrawalFeeAmount));
    }
  }

  function beforeDeposit() external override {
    if (harvestOnDeposit) {
      require(msg.sender == vault, "!vault");
      _harvest(nullAddress);
    }
  }

  // performance fees
  function chargeFees(address callFeeRecipient) internal override {
    // take fee from output
    uint256 toNative = IERC20(output).balanceOf(address(this)).mul(45).div(
      1000
    );

    _safeSwap(toNative, outputToNativeRoute, address(this));

    uint256 nativeBal = IERC20(native).balanceOf(address(this));

    uint256 callFeeAmount = nativeBal.mul(callFee).div(MAX_FEE);
    if (callFeeRecipient != nullAddress) {
      IERC20(native).safeTransfer(callFeeRecipient, callFeeAmount);
    } else {
      IERC20(native).safeTransfer(tx.origin, callFeeAmount);
    }

    uint256 autocompFeeAmount = nativeBal.mul(autocompFee).div(MAX_FEE);
    IERC20(native).safeTransfer(autocompFeeRecipient, autocompFeeAmount);

    uint256 strategistFee = nativeBal.mul(STRATEGIST_FEE).div(MAX_FEE);
    IERC20(native).safeTransfer(strategist, strategistFee);
  }

  // calculate the total underlaying 'want' held by the strat.
  function balanceOf() public view returns (uint256) {
    return balanceOfWant().add(balanceOfPool());
  }

  // it calculates how much 'want' this contract holds.
  function balanceOfWant() public view returns (uint256) {
    return IERC20(want).balanceOf(address(this));
  }

  // it calculates how much 'want' the strategy has working in the farm.
  function balanceOfPool() public view returns (uint256) {
    uint256 _amount = IStakingRewards(chef).balanceOf(address(this));

    return _amount;
  }

  // called as part of strat migration. Sends all the available funds back to the vault.
  function retireStrat() external {
    require(msg.sender == vault, "!vault");

    IStakingRewards(chef).withdraw(balanceOfPool());

    uint256 wantBal = IERC20(want).balanceOf(address(this));
    IERC20(want).transfer(vault, wantBal);
  }

  function setHarvestOnDeposit(bool _harvestOnDeposit) external onlyManager {
    harvestOnDeposit = _harvestOnDeposit;

    if (harvestOnDeposit) {
      setWithdrawalFee(0);
    } else {
      setWithdrawalFee(10);
    }
  }

  function _safeSwap(
    uint256 _amountIn,
    address[] memory _path,
    address _to
  ) internal override {
    // swapExactTokensForTokens
    emit _SafeSwap(_amountIn, 0, _path, _to, block.timestamp.add(600));

    IUniswapRouterETH(unirouter).swapExactTokensForTokens(
      _amountIn,
      0,
      _path,
      _to,
      block.timestamp.add(600)
    );
  }

  function _addLiquidity(uint256 lp0Bal, uint256 lp1Bal) internal override {
    IUniswapRouterETH(unirouter).addLiquidity(
      lpToken0,
      lpToken1,
      lp0Bal,
      lp1Bal,
      1,
      1,
      address(this),
      block.timestamp
    );
  }

  // pauses deposits and withdraws all funds from third party systems.
  function panic() public onlyManager {
    pause();
    IStakingRewards(chef).withdraw(balanceOfPool());
  }

  function pause() public onlyManager {
    _pause();

    _removeAllowances();
  }

  function unpause() external onlyManager {
    _unpause();

    _giveAllowances();

    deposit();
  }

  function _giveAllowances() internal {
    IERC20(want).safeApprove(chef, type(uint256).max);
    IERC20(output).safeApprove(unirouter, type(uint256).max);
    IERC20(lpToken0).safeApprove(unirouter, 0);
    IERC20(lpToken0).safeApprove(unirouter, type(uint256).max);
    IERC20(lpToken1).safeApprove(unirouter, 0);
    IERC20(lpToken1).safeApprove(unirouter, type(uint256).max);
    IERC20(output2).safeApprove(unirouter, 0);
    IERC20(output2).safeApprove(unirouter, type(uint256).max);
  }

  function _removeAllowances() internal {
    IERC20(want).safeApprove(chef, 0);
    IERC20(output).safeApprove(unirouter, 0);
    IERC20(lpToken0).safeApprove(unirouter, 0);
    IERC20(lpToken1).safeApprove(unirouter, 0);
  }
}
