// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/IERC20.sol';

interface IWETH is IERC20 {
  function deposit() external payable;

  function withdraw(uint amount) external;
}
