import pytest
import brownie
from brownie import a, web3, MockNFT, MockERC20, MockWETH, OpenOcean

domain_type = [
    {'name': 'name', 'type': 'string'},
    {'name': 'version', 'type': 'string'},
    {'name': 'chainId', 'type': 'uint256'},
    {'name': 'verifyingContract', 'type': 'address'},
]

order_type = [
    {'name': 'maker', 'type': 'address'},
    {'name': 'nft', 'type': 'address'},
    {'name': 'id', 'type': 'uint256'},
    {'name': 'isBuy', 'type': 'bool'},
    {'name': 'cost', 'type': 'uint256'},
    {'name': 'expiration', 'type': 'uint64'},
    {'name': 'salt', 'type': 'uint64'},
]

operator_type = [
    {'name': 'mhash', 'type': 'bytes32'},
    {'name': 'deadline', 'type': 'uint64'},
]


def order_array(order):
    return [order.get(e['name']) for e in order_type]


def signTypedData(acc, data):
    return web3.eth.signTypedData(acc.address, data).hex()


def sign_maker(acc, mkt, order):
    return signTypedData(acc, {
        'types': {'EIP712Domain': domain_type, 'Order': order_type},
        'domain': {
            'name': 'OpenOcean',
            'version': '1',
            'chainId': 1,
            'verifyingContract': mkt.address,
        },
        'primaryType': 'Order',
        'message': order,
    })


def sign_operator(acc, mkt, order, deadline):
    return signTypedData(acc, {
        'types': {'EIP712Domain': domain_type, 'Operator': operator_type},
        'domain': {
            'name': 'OpenOcean',
            'version': '1',
            'chainId': 1,
            'verifyingContract': mkt.address,
        },
        'primaryType': 'Operator',
        'message': {'mhash': '0x'+mkt.makerSignHash(order_array(order)).hex(), 'deadline': deadline},
    })


def test_basic_maker_sell():
    mkt = OpenOcean.deploy({'from': a[0]})
    mkt.grantRole(mkt.OPERATOR_ROLE(), a[1], {'from': a[0]})
    nft = MockNFT.deploy({'from': a[0]})
    order = {
        'maker': a[7].address,
        'nft': nft.address,
        'id': 42,
        'isBuy': False,
        'cost': str(10 * 10**18),
        'expiration': 2000000000,
        'salt': 0,
    }
    nft.mint(a[7], 42, {'from': a[0]})
    nft.setApprovalForAll(mkt, True, {'from': a[7]})
    assert nft.ownerOf(42) == a[7]
    msig = sign_maker(a[7], mkt, order)
    osig = sign_operator(a[1], mkt, order, 3000000000)
    mkt.trade(order_array(order), msig, 3000000000, osig, {'from': a[8], 'value': '10 ether'})
    assert nft.ownerOf(42) == a[8]
    assert mkt.balanceOf(a[7]) == 10 * 10**18


def test_basic_maker_buy():
    mkt = OpenOcean.deploy({'from': a[0]})
    mkt.grantRole(mkt.OPERATOR_ROLE(), a[1], {'from': a[0]})
    nft = MockNFT.deploy({'from': a[0]})
    order = {
        'maker': a[8].address,
        'nft': nft.address,
        'id': 42,
        'isBuy': True,
        'cost': str(10 * 10**18),
        'expiration': 2000000000,
        'salt': 0,
    }
    nft.mint(a[7], 42, {'from': a[0]})
    nft.setApprovalForAll(mkt, True, {'from': a[7]})
    assert nft.ownerOf(42) == a[7]
    msig = sign_maker(a[8], mkt, order)
    osig = sign_operator(a[1], mkt, order, 3000000000)
    mkt.deposit({'from': a[8], 'value': '30 ether'})
    mkt.trade(order_array(order), msig, 3000000000, osig, {'from': a[7]})
    assert nft.ownerOf(42) == a[8]
    assert mkt.balanceOf(a[7]) == 10 * 10**18
    assert mkt.balanceOf(a[8]) == 20 * 10**18
