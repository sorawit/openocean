import pytest
import brownie
from brownie import a, web3, MockNFT, MockERC20, MarketPlace


def order_hash(market, order):
    return web3.solidityKeccak(
        [
            'address', 'address', 'address', 'uint256', 'bool', 'uint256', 'address', 'uint64', 'uint64'
        ],
        [market] + order_array(order),
    )


def order_array(order):
    return [
        order['maker'],
        order['nft'],
        order['id'],
        order['isBuy'],
        order['cost'],
        order['denom'],
        order['expr'],
        order['salt'],
    ]


def sign(acc, hex):
    sigx = web3.eth.sign(acc.address, hexstr=hex).hex()
    return (int.from_bytes(bytes.fromhex(sigx[2:]), 'big') + 27).to_bytes(65, 'big').hex()


def test_basic_maker_sell():
    mkt = MarketPlace.deploy({'from': a[0]})
    nft = MockNFT.deploy({'from': a[0]})
    usd = MockERC20.deploy({'from': a[0]})
    order = {
        'maker': a[7].address,
        'nft': nft.address,
        'id': 42,
        'isBuy': False,
        'cost': 100 * 10**18,
        'denom': usd.address,
        'expr': 2000000000,
        'salt': 0,
    }
    nft.mint(a[7], 42, {'from': a[0]})
    usd.mint(a[8], 1000 * 10**18, {'from': a[0]})
    nft.setApprovalForAll(mkt, True, {'from': a[7]})
    usd.approve(mkt, 2**256 - 1, {'from': a[8]})
    assert nft.ownerOf(42) == a[7]
    assert usd.balanceOf(a[8]) == 1000 * 10**18
    sig = sign(a[7], order_hash(mkt.address, order).hex())
    mkt.trade(order_array(order), sig, {'from': a[8]})
    assert nft.ownerOf(42) == a[8]
    assert usd.balanceOf(a[7]) == 100 * 10**18
    assert usd.balanceOf(a[8]) == 900 * 10**18


def test_basic_maker_buy():
    mkt = MarketPlace.deploy({'from': a[0]})
    nft = MockNFT.deploy({'from': a[0]})
    usd = MockERC20.deploy({'from': a[0]})
    order = {
        'maker': a[8].address,
        'nft': nft.address,
        'id': 42,
        'isBuy': True,
        'cost': 100 * 10**18,
        'denom': usd.address,
        'expr': 2000000000,
        'salt': 0,
    }
    nft.mint(a[7], 42, {'from': a[0]})
    usd.mint(a[8], 1000 * 10**18, {'from': a[0]})
    nft.setApprovalForAll(mkt, True, {'from': a[7]})
    usd.approve(mkt, 2**256 - 1, {'from': a[8]})
    assert nft.ownerOf(42) == a[7]
    assert usd.balanceOf(a[8]) == 1000 * 10**18
    sig = sign(a[8], order_hash(mkt.address, order).hex())
    mkt.trade(order_array(order), sig, {'from': a[7]})
    assert nft.ownerOf(42) == a[8]
    assert usd.balanceOf(a[7]) == 100 * 10**18
    assert usd.balanceOf(a[8]) == 900 * 10**18
