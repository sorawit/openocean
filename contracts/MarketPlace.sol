// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/access/Ownable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/Pausable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/ReentrancyGuard.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/cryptography/ECDSA.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/cryptography/SignatureChecker.sol';

struct Order {
  address maker; // The order's maker
  address nft; // The NFT contract address to be traded
  uint id; // The NFT id to be traded
  bool isBuy; // Whether the maker wants to buy or sell the NFT
  uint cost; // How many denom tokens does it cost to perform trade
  address denom; // The ERC20 contract address for denominator
  uint64 expr; // Expiration timestamp in UNIX epoch
  uint64 salt; // Unique salt
}

/// @dev Decentralized market place for trading NFTs without fees. Although the contract is
/// ownable, the only action that the owner can do is to stop trading activity. CANNOT STEAL FUNDS.
contract MarketPlace is Ownable, Pausable, ReentrancyGuard {
  using SafeERC20 for IERC20;
  mapping(bytes32 => bool) public gone;

  /// @dev Emergency call by the governor to stop trading activity. CANNOT STEAL FUNDS.
  function pause() external onlyOwner {
    _pause();
  }

  /// @dev Unpause this contract and allow trading activity to continue.
  function unpause() external onlyOwner {
    _unpause();
  }

  /// @dev Perform a trade, using ord.maker+sig as maker and msg.sender as taker.
  function trade(Order memory ord, bytes memory sig) external whenNotPaused nonReentrant {
    require(ord.expr > block.timestamp, '!expr');
    require(ord.maker != msg.sender && ord.maker != address(this), '!maker');
    require(ord.nft != msg.sender && ord.nft != address(this), '!nft');
    require(ord.denom != msg.sender && ord.denom != address(this), '!denom');
    bytes32 hash = getOrderHash(ord);
    require(!gone[hash], '!gone');
    gone[hash] = true;
    bytes32 sign = ECDSA.toEthSignedMessageHash(hash);
    require(SignatureChecker.isValidSignatureNow(ord.maker, sign, sig), '!sig');
    address buyer = ord.isBuy ? ord.maker : msg.sender;
    address seller = ord.isBuy ? msg.sender : ord.maker;
    IERC20(ord.denom).safeTransferFrom(buyer, seller, ord.cost);
    IERC721(ord.nft).safeTransferFrom(seller, buyer, ord.id, '');
  }

  /// @dev Cancel a specific order, marking it gone to disallow anyone to trade against it.
  function cancel(Order memory ord) external nonReentrant {
    require(ord.maker == msg.sender, '!maker');
    bytes32 hash = getOrderHash(ord);
    require(!gone[hash], '!gone');
    gone[hash] = true;
  }

  /// @dev Helper function to get the unique hash of a given order.
  function getOrderHash(Order memory ord) public view returns (bytes32) {
    // prettier-ignore
    return keccak256(abi.encodePacked(
      address(this), ord.maker, ord.nft, ord.id, ord.isBuy,
      ord.cost, ord.denom, ord.expr, ord.salt
    ));
  }
}
