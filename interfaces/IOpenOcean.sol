// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

struct Order {
  address maker; // The order's maker
  address nft; // The NFT contract address to be traded
  uint id; // The NFT id to be traded
  bool isBuy; // Whether the maker wants to buy or sell the NFT
  uint cost; // How many unit tokens does it cost to perform trade
  address unit; // The ERC20 contract address for cost unit
  uint64 expiration; // Expiration timestamp in UNIX epoch
  uint64 salt; // Unique salt
}

interface IOpenOcean {
  function trade(
    Order memory ord,
    bytes memory msig,
    uint64 deadline,
    bytes memory osig,
    address beneficiary
  ) external;
}
