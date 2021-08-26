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
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/cryptography/draft-EIP712.sol';
import '../interfaces/IOpenOcean.sol';

/// @dev Decentralized market place for trading NFTs without fees. Although the contract has
/// access control, the most the owner can do is stopping trading activity. CANNOT STEAL FUNDS.
contract OpenOcean is AccessControl, Pausable, ReentrancyGuard, EIP712, IOpenOcean {
  using SafeERC20 for IERC20;

  bytes32 public OPERATOR_ROLE = keccak256('OPERATOR_ROLE');
  mapping(bytes32 => bool) public gone;

  // prettier-ignore
  bytes32 public immutable _ORDER_TYPEHASH =
    keccak256('Order(address maker,address nft,uint256 id,bool isBuy,uint256 cost,address unit,uint64 expiration,uint64 salt)');
  bytes32 public immutable _OPERATOR_TYPEHASH =
    keccak256('Operator(bytes32 mhash,uint64 deadline)');

  constructor() EIP712('OpenOcean', '1') {
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
    bytes memory osig,
    address beneficiary
  ) external override whenNotPaused nonReentrant {
    require(deadline > block.timestamp, '!deadline');
    require(ord.expiration > block.timestamp, '!expiration');
    require(ord.maker != msg.sender && ord.maker != beneficiary, '!maker');
    bytes32 mhash = makerSignHash(ord);
    require(!gone[mhash], '!gone');
    gone[mhash] = true;
    require(SignatureChecker.isValidSignatureNow(ord.maker, mhash, msig), '!msig');
    bytes32 ohash = operatorSignHash(mhash, deadline);
    require(hasRole(OPERATOR_ROLE, ECDSA.recover(ohash, osig)), '!osig');
    if (ord.isBuy) {
      IERC20(ord.unit).safeTransferFrom(ord.maker, beneficiary, ord.cost);
      IERC721(ord.nft).safeTransferFrom(msg.sender, ord.maker, ord.id, '');
    } else {
      IERC20(ord.unit).safeTransferFrom(msg.sender, ord.maker, ord.cost);
      IERC721(ord.nft).safeTransferFrom(ord.maker, beneficiary, ord.id, '');
    }
  }

  /// @dev Cancel a specific order, marking it gone to disallow anyone to trade against it.
  function cancel(Order memory ord) external nonReentrant {
    require(ord.maker == msg.sender, '!maker');
    bytes32 mhash = makerSignHash(ord);
    require(!gone[mhash], '!gone');
    gone[mhash] = true;
  }

  /// @dev Helper function to get the unique hash for maker to sign.
  function makerSignHash(Order memory ord) public view returns (bytes32) {
    // prettier-ignore
    return _hashTypedDataV4(keccak256(abi.encode(
      _ORDER_TYPEHASH, ord.maker, ord.nft, ord.id, ord.isBuy,
      ord.cost, ord.unit, ord.expiration, ord.salt
    )));
  }

  /// @dev Helper function to get the unique hash for operator to sign.
  function operatorSignHash(bytes32 mhash, uint64 deadline) public view returns (bytes32) {
    return _hashTypedDataV4(keccak256(abi.encode(_OPERATOR_TYPEHASH, mhash, deadline)));
  }
}
