// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../interfaces/synthetix/IStakingRewards.sol";

import "./StratManager.sol";

abstract contract BaseStrategySingleLP is StratManager {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  // Tokens used
  address public native;
  address public output;
  address public want;
  address public lpToken0;
  address public lpToken1;
  address constant nullAddress = address(0);

  // Third party contracts
  address public chef;

  uint256 public lastHarvest;

  // Routes
  address[] public outputToNativeRoute;
  address[] public outputToLp0Route;
  address[] public outputToLp1Route;

  function chargeFees(address) internal virtual;

  function deposit() public virtual;

  function _safeSwap(
    uint256 _amountIn,
    address[] memory _path,
    address _to
  ) internal virtual;

  function _addLiquidity(uint256 lp0Bal, uint256 lp1Bal) internal virtual;

  //events
  event StratHarvest(address indexed harvester);

  function harvest() external virtual onlyHarvester {
    _harvest(nullAddress);
  }

  function harvestWithCallFeeRecipient(address callFeeRecipient)
    external
    virtual
    onlyHarvester
  {
    _harvest(callFeeRecipient);
  }

  function managerHarvest() external onlyManager {
    _harvest(nullAddress);
  }

  // compounds earnings and charges performance fee
  function _harvest(address callFeeRecipient) internal whenNotPaused {
    IStakingRewards(chef).getReward();
    uint256 outputBal = IERC20(output).balanceOf(address(this));
    if (outputBal > 0) {
      chargeFees(callFeeRecipient);
      addLiquidity();
      deposit();
      lastHarvest = block.timestamp;
      emit StratHarvest(msg.sender);
    }
  }

  // Adds liquidity to AMM and gets more LP tokens.
  function addLiquidity() internal {
    uint256 outputHalf = IERC20(output).balanceOf(address(this)).div(2);

    if (lpToken0 != output) {
      _safeSwap(outputHalf, outputToLp0Route, address(this));
    }

    if (lpToken1 != output) {
      _safeSwap(outputHalf, outputToLp1Route, address(this));
    }

    uint256 lp0Bal = IERC20(lpToken0).balanceOf(address(this));
    uint256 lp1Bal = IERC20(lpToken1).balanceOf(address(this));
    if (lp0Bal > 0 && lp1Bal > 0) {
      _addLiquidity(lp0Bal, lp1Bal);
    }
  }
}
