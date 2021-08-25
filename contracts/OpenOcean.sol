// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/access/AccessControl.sol';
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
  uint cost; // How many unit tokens does it cost to perform trade
  address unit; // The ERC20 contract address for cost unit
  uint64 expiration; // Expiration timestamp in UNIX epoch
  uint64 salt; // Unique salt
}

/// @dev Decentralized market place for trading NFTs without fees. Although the contract has
/// access control, the most the owner can do is stopping trading activity. CANNOT STEAL FUNDS.
contract OpenOcean is AccessControl, Pausable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  bytes32 public OPERATOR_ROLE = keccak256('OPERATOR_ROLE');
  mapping(bytes32 => bool) public gone;

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /// @dev Emergency call by the governor to stop trading activity. CANNOT STEAL FUNDS.
  function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  /// @dev Unpause this contract and allow trading activity to continue.
  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  /// @dev Perform a trade, using ord.maker+sig as maker and msg.sender as taker.
  function trade(
    Order memory ord,
    bytes memory msig,
    uint64 deadline,
    bytes memory osig
  ) external whenNotPaused nonReentrant {
    require(deadline > block.timestamp, '!deadline');
    require(ord.expiration > block.timestamp, '!expiration');
    require(ord.maker != msg.sender && ord.maker != address(this), '!maker');
    require(ord.nft != msg.sender && ord.nft != address(this) && ord.nft != ord.maker, '!nft');
    require(ord.unit != msg.sender && ord.unit != address(this) && ord.unit != ord.maker, '!unit');
    bytes32 hash = getOrderHash(ord);
    require(!gone[hash], '!gone');
    gone[hash] = true;
    bytes32 msign = ECDSA.toEthSignedMessageHash(hash);
    require(SignatureChecker.isValidSignatureNow(ord.maker, msign, msig), '!msig');
    bytes32 osign = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(hash, deadline)));
    require(hasRole(OPERATOR_ROLE, ECDSA.recover(osign, osig)), '!osig');
    address buyer = ord.isBuy ? ord.maker : msg.sender;
    address seller = ord.isBuy ? msg.sender : ord.maker;
    IERC20(ord.unit).safeTransferFrom(buyer, seller, ord.cost);
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
      block.chainid, address(this), ord.maker, ord.nft, ord.id, ord.isBuy,
      ord.cost, ord.unit, ord.expiration, ord.salt
    ));
  }
}