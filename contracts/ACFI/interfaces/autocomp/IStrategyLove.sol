// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IStrategy.sol";

interface IStrategyLove is IStrategy {
  function balanceOfLove() external view returns (uint256);

  function loveToken() external view returns (IERC20);

  function withdrawLove(uint256) external;
}
