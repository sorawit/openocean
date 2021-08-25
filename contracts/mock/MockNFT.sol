// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/ERC721.sol';

contract MockNFT is ERC721('MockNFT', 'NFT') {
  function mint(address to, uint tokenId) external {
    _safeMint(to, tokenId);
  }
}
