// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/cryptography/ECDSA.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/cryptography/SignatureChecker.sol';

contract MarketPlace is Initializable {
  using SafeERC20 for IERC20;

  event SetGovernor(address governor);
  event SetCFO(address cfo);
  event SetAllowedNFT(address nft, bool ok);
  event SetAllowedDenom(address denom, bool ok);

  struct Order {
    address maker;
    address nft;
    uint id;
    bool isBuy;
    uint cost;
    uint fee;
    address denom;
    uint64 expr;
    uint64 salt;
  }

  uint private unlocked;
  address public governor;
  address public pendingGovernor;
  address public cfo;

  mapping(bytes32 => bool) public gone;
  mapping(address => bool) public allowedNFTs;
  mapping(address => bool) public allowedDenoms;

  modifier lock() {
    require(unlocked == 1, '!lock');
    unlocked = 2;
    _;
    unlocked = 1;
  }

  modifier gov() {
    require(msg.sender == governor, '!gov');
    _;
  }

  function initialize(address _governor, address _cfo) external initializer {
    unlocked = 1;
    governor = _governor;
    cfo = _cfo;
    emit SetGovernor(_governor);
    emit SetCFO(_cfo);
  }

  function setPendingGovernor(address _pendingGovernor) external gov {
    pendingGovernor = _pendingGovernor;
  }

  function acceptGovernor() external {
    require(msg.sender == pendingGovernor, '!pending');
    pendingGovernor = address(0);
    governor = msg.sender;
    emit SetGovernor(msg.sender);
  }

  function setCFO(address _cfo) external gov {
    cfo = _cfo;
    emit SetCFO(_cfo);
  }

  function setAllowedNFTs(address[] calldata nfts, bool allowed) external gov {
    for (uint idx = 0; idx < nfts.length; idx++) {
      allowedNFTs[nfts[idx]] = allowed;
      emit SetAllowedNFT(nfts[idx], allowed);
    }
  }

  function setAllowedDenoms(address[] calldata denoms, bool allowed) external gov {
    for (uint idx = 0; idx < denoms.length; idx++) {
      allowedDenoms[denoms[idx]] = allowed;
      emit SetAllowedDenom(denoms[idx], allowed);
    }
  }

  function trade(Order memory ord, bytes memory sig) external lock {
    require(ord.expr < block.timestamp, '!expr');
    require(ord.maker != msg.sender, '!self');
    require(allowedNFTs[ord.nft], '!nft');
    require(allowedDenoms[ord.denom], '!denom');
    bytes32 hash = getOrderHash(ord);
    require(!gone[hash], '!gone');
    gone[hash] = true;
    bytes32 sign = ECDSA.toEthSignedMessageHash(hash);
    require(SignatureChecker.isValidSignatureNow(ord.maker, sign, sig), '!sig');
    address buyer = ord.isBuy ? ord.maker : msg.sender;
    address seller = ord.isBuy ? msg.sender : ord.maker;
    IERC20(ord.denom).safeTransferFrom(seller, buyer, ord.cost - ord.fee);
    IERC20(ord.denom).safeTransferFrom(seller, cfo, ord.fee);
    IERC721(ord.nft).safeTransferFrom(buyer, seller, ord.id, bytes(''));
  }

  function cancel(Order memory ord) external lock {
    require(ord.maker == msg.sender, '!maker');
    bytes32 hash = getOrderHash(ord);
    require(!gone[hash], '!gone');
    gone[hash] = true;
  }

  function getOrderHash(Order memory ord) public view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          address(this),
          ord.maker,
          ord.nft,
          ord.id,
          ord.isBuy,
          ord.fee,
          ord.cost,
          ord.denom,
          ord.expr,
          ord.salt
        )
      );
  }
}
