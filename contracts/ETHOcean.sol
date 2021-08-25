// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';

import '../interfaces/IOpenOcean.sol';
import '../interfaces/IWETH.sol';

contract ETHOcean {
  IOpenOcean public immutable ocean;
  IWETH public immutable weth;

  constructor(address _ocean, address _weth) payable {
    weth = IWETH(_weth);
    ocean = IOpenOcean(_ocean);
    IWETH(_weth).deposit{value: msg.value}();
    IWETH(_weth).approve(_ocean, type(uint).max);
  }

  function buyWithETH(
    Order calldata ord,
    bytes calldata msig,
    uint64 deadline,
    bytes calldata osig
  ) external payable {
    require(!ord.isBuy, '!isBuy');
    require(ord.unit == address(weth), '!unit');
    require(ord.cost == msg.value, '!cost');
    weth.deposit{value: msg.value}();
    ocean.trade(ord, msig, deadline, osig, msg.sender);
  }
}
