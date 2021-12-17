// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/autocomp/IStrategy.sol";

/**
 * @dev Implementation of a vault to deposit funds for yield optimizing.
 * This is the contract that receives funds and that users interface with.
 * The yield optimizing strategy itself is implemented in a separate 'Strategy.sol' contract.
 */
contract TestVault is ERC20, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  struct StratCandidate {
    address implementation;
    uint256 proposedTime;
  }

  address public strategy;
  uint256 public blocknumber;
  uint256 public blocktimestamp;
  uint256 public rBal;

  // The last proposed strategy to switch to.
  StratCandidate public stratCandidate;
  // The minimum time it has to pass before a strat candidate can be approved.
  uint256 public immutable approvalDelay;

  event NewStratCandidate(address implementation);
  event UpgradeStrat(address implementation);

  constructor(
    address _strategy,
    string memory _name,
    string memory _symbol,
    uint256 _approvalDelay
  ) public ERC20(_name, _symbol) {
    strategy = _strategy;
    approvalDelay = _approvalDelay;
    blocktimestamp = block.timestamp;
    blocknumber = block.number;
  }

  function want() public view returns (IERC20) {
    return IStrategy(strategy).want();
  }

  function balance() public view returns (uint256) {
    return want().balanceOf(address(this)).add(IStrategy(strategy).balanceOf());
  }

  function available() public view returns (uint256) {
    return want().balanceOf(address(this));
  }

  function getPricePerFullShare() public view returns (uint256) {
    return totalSupply() == 0 ? 1e18 : balance().mul(1e18).div(totalSupply());
  }

  /**
   * @dev A helper function to call deposit() with all the sender's funds.
   */
  function depositAll() external {
    deposit(want().balanceOf(msg.sender));
  }

  /**
   * @dev The entrypoint of funds into the system. People deposit with this function
   * into the vault. The vault is then in charge of sending funds into the strategy.
   */
  function deposit(uint256 _amount) public nonReentrant {
    // strategy.beforeDeposit();

    uint256 _pool = balance();
    want().safeTransferFrom(msg.sender, address(this), _amount);
    earn();
    uint256 _after = balance();
    _amount = _after.sub(_pool); // Additional check for deflationary tokens
    uint256 shares = 0;
    if (totalSupply() == 0) {
      shares = _amount;
    } else {
      shares = (_amount.mul(totalSupply())).div(_pool);
    }
    _mint(msg.sender, shares);
  }

  /**
   * @dev Function to send funds into the strategy and put them to work. It's primarily called
   * by the vault's deposit() function.
   */
  function earn() public {
    uint256 _bal = available();
    want().safeTransfer(address(strategy), _bal);
    IStrategy(strategy).deposit();
  }

  /**
   * @dev A helper function to call withdraw() with all the sender's funds.
   */
  function withdrawAll() external {
    withdraw(balanceOf(msg.sender));
  }

  /**
   * @dev Function to exit the system. The vault will withdraw the required tokens
   * from the strategy and pay up the token holder. A proportional number of IOU
   * tokens are burned in the process.
   */
  function withdraw(uint256 _shares) public {
    uint256 r = (balance().mul(_shares)).div(totalSupply());
    _burn(msg.sender, _shares);

    uint256 b = want().balanceOf(address(this));
    if (b < r) {
      uint256 _withdraw = r.sub(b);
      IStrategy(strategy).withdraw(_withdraw);
      uint256 _after = want().balanceOf(address(this));
      uint256 _diff = _after.sub(b);
      if (_diff < _withdraw) {
        r = b.add(_diff);
      }
    }

    want().safeTransfer(msg.sender, r);
  }

  /**
   * @dev Sets the candidate for the new strat to use with this vault.
   * @param _implementation The address of the candidate strategy.
   */
  function proposeStrat(address _implementation) public onlyOwner {
    require(
      address(this) == IStrategy(_implementation).vault(),
      "Proposal not valid for this Vault"
    );
    stratCandidate = StratCandidate({
      implementation: _implementation,
      proposedTime: block.timestamp
    });

    emit NewStratCandidate(_implementation);
  }

  /**
   * @dev It switches the active strat for the strat candidate. After upgrading, the
   * candidate implementation is set to the 0x00 address, and proposedTime to a time
   * happening in +100 years for safety.
   */

  function upgradeStrat() public onlyOwner {
    require(
      stratCandidate.implementation != address(0),
      "There is no candidate"
    );
    require(
      stratCandidate.proposedTime.add(approvalDelay) < block.timestamp,
      "Delay has not passed"
    );

    emit UpgradeStrat(stratCandidate.implementation);

    IStrategy(strategy).retireStrat();
    strategy = stratCandidate.implementation;
    stratCandidate.implementation = address(0);
    stratCandidate.proposedTime = 5000000000;

    earn();
  }

  /**
   * @dev Rescues random funds stuck that the strat can't handle.
   * @param _token address of the token to rescue.
   */
  function inCaseTokensGetStuck(address _token) external onlyOwner {
    require(_token != address(want()), "!token");

    uint256 amount = IERC20(_token).balanceOf(address(this));
    IERC20(_token).safeTransfer(msg.sender, amount);
  }
}