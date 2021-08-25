// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20('MockERC20', 'ERC20') {
  function mint(address to, uint amount) external {
    _mint(to, amount);
  }
}
