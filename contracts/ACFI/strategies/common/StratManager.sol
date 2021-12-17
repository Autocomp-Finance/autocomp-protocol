// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StratManager is Ownable, Pausable {
  /**
   * @dev Autocomp Contracts:
   * {keeper} - Address to manage a few lower risk features of the strat
   * {strategist} - Address of the strategy author/deployer where strategist fee will go.
   * {vault} - Address of the vault that controls the strategy's funds.
   * {unirouter} - Address of exchange to execute swaps.
   */
  address public keeper;
  address public strategist;
  address public unirouter;
  address public vault;
  address public harvester;
  address public autocompFeeRecipient;

  struct StratMgr {
    address keeper;
    address strategist;
    address unirouter;
    address vault;
    address harvester;
    address autocompFeeRecipient;
  }

  /**
   * @dev Initializes the base strategy.
   * @param stratMgr.keeper address to use as alternative owner.
   * @param stratMgr.strategist address where strategist fees go.
   * @param stratMgr.unirouter router to use for swaps
   * @param stratMgr.vault address of parent vault.
   * @param stratMgr.autocompFeeRecipient address where to send autocomp's fees.
   */
  constructor(StratMgr memory stratMgr) public {
    keeper = stratMgr.keeper;
    strategist = stratMgr.strategist;
    unirouter = stratMgr.unirouter;
    vault = stratMgr.vault;
    harvester = stratMgr.harvester;
    autocompFeeRecipient = stratMgr.autocompFeeRecipient;
  }

  // checks that caller is either owner or keeper.
  modifier onlyManager() {
    require(msg.sender == owner() || msg.sender == keeper, "!manager");
    _;
  }

  // checks that caller is harvestr.
  modifier onlyHarvester() {
    require(msg.sender == harvester, "!harvester");
    _;
  }

  /**
   * @dev Updates address of the strat keeper.
   * @param _keeper new keeper address.
   */
  function setKeeper(address _keeper) external onlyManager {
    keeper = _keeper;
  }

  /**
   * @dev Updates address of the strat harvester.
   * @param _harvester new harvester address.
   */
  function setHarvester(address _harvester) external onlyManager {
    harvester = _harvester;
  }

  /**
   * @dev Updates address where strategist fee earnings will go.
   * @param _strategist new strategist address.
   */
  function setStrategist(address _strategist) external {
    require(msg.sender == strategist, "!strategist");
    strategist = _strategist;
  }

  /**
   * @dev Updates router that will be used for swaps.
   * @param _unirouter new unirouter address.
   */
  function setUnirouter(address _unirouter) external onlyOwner {
    unirouter = _unirouter;
  }

  /**
   * @dev Updates parent vault.
   * @param _vault new vault address.
   */
  function setVault(address _vault) external onlyOwner {
    vault = _vault;
  }

  /**
   * @dev Updates autocomp fee recipient.
   * @param _autocompFeeRecipient new autocomp fee recipient address.
   */
  function setAutocompFeeRecipient(address _autocompFeeRecipient)
    external
    onlyOwner
  {
    autocompFeeRecipient = _autocompFeeRecipient;
  }

  /**
   * @dev Function to synchronize balances before new user deposit.
   * Can be overridden in the strategy.
   */
  function beforeDeposit() external virtual {}
}
