import pytest
import brownie
from brownie import a, web3, MockNFT, MockERC20, OpenOcean


def order_hash(market, order):
    return web3.solidityKeccak(
        [
            'uint256', 'address', 'address', 'address', 'uint256', 'bool', 'uint256', 'address', 'uint64', 'uint64'
        ],
        [1, market] + order_array(order),
    ).hex()


def operator_hash(market, order, deadline):
    return web3.solidityKeccak(['bytes32', 'uint64'], [order_hash(market, order), deadline]).hex()


def order_array(order):
    return [
        order['maker'],
        order['nft'],
        order['id'],
        order['isBuy'],
        order['cost'],
        order['unit'],
        order['expr'],
        order['salt'],
    ]


def sign(acc, hex):
    sigx = web3.eth.sign(acc.address, hexstr=hex).hex()
    return (int.from_bytes(bytes.fromhex(sigx[2:]), 'big') + 27).to_bytes(65, 'big').hex()


def test_basic_maker_sell():
    mkt = OpenOcean.deploy({'from': a[0]})
    mkt.grantRole(mkt.OPERATOR_ROLE(), a[1], {'from': a[0]})
    nft = MockNFT.deploy({'from': a[0]})
    usd = MockERC20.deploy({'from': a[0]})
    order = {
        'maker': a[7].address,
        'nft': nft.address,
        'id': 42,
        'isBuy': False,
        'cost': 100 * 10**18,
        'unit': usd.address,
        'expr': 2000000000,
        'salt': 0,
    }
    nft.mint(a[7], 42, {'from': a[0]})
    usd.mint(a[8], 1000 * 10**18, {'from': a[0]})
    nft.setApprovalForAll(mkt, True, {'from': a[7]})
    usd.approve(mkt, 2**256 - 1, {'from': a[8]})
    assert nft.ownerOf(42) == a[7]
    assert usd.balanceOf(a[8]) == 1000 * 10**18
    msig = sign(a[7], order_hash(mkt.address, order))
    osig = sign(a[1], operator_hash(mkt.address, order, 3000000000))
    mkt.trade(order_array(order), msig, 3000000000, osig, {'from': a[8]})
    assert nft.ownerOf(42) == a[8]
    assert usd.balanceOf(a[7]) == 100 * 10**18
    assert usd.balanceOf(a[8]) == 900 * 10**18


def test_basic_maker_buy():
    mkt = OpenOcean.deploy({'from': a[0]})
    mkt.grantRole(mkt.OPERATOR_ROLE(), a[1], {'from': a[0]})
    nft = MockNFT.deploy({'from': a[0]})
    usd = MockERC20.deploy({'from': a[0]})
    order = {
        'maker': a[8].address,
        'nft': nft.address,
        'id': 42,
        'isBuy': True,
        'cost': 100 * 10**18,
        'unit': usd.address,
        'expr': 2000000000,
        'salt': 0,
    }
    nft.mint(a[7], 42, {'from': a[0]})
    usd.mint(a[8], 1000 * 10**18, {'from': a[0]})
    nft.setApprovalForAll(mkt, True, {'from': a[7]})
    usd.approve(mkt, 2**256 - 1, {'from': a[8]})
    assert nft.ownerOf(42) == a[7]
    assert usd.balanceOf(a[8]) == 1000 * 10**18
    msig = sign(a[8], order_hash(mkt.address, order))
    osig = sign(a[1], operator_hash(mkt.address, order, 3000000000))
    tx = mkt.trade(order_array(order), msig, 3000000000, osig, {'from': a[7]})
    print(tx.gas_used)
    assert nft.ownerOf(42) == a[8]
    assert usd.balanceOf(a[7]) == 100 * 10**18
    assert usd.balanceOf(a[8]) == 900 * 10**18
