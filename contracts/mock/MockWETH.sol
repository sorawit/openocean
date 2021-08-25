// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/ERC20.sol';

contract MockWETH is ERC20('MockWETH', 'WETH') {
  function deposit() external payable {
    _mint(msg.sender, msg.value);
  }

  function withdraw(uint amount) external {
    _burn(msg.sender, amount);
    payable(msg.sender).transfer(amount);
  }
}
