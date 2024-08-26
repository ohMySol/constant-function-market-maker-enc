// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface CfmmErrors {
    /**
     * @dev Error indicates that user provided not enough token amount
     * in the `swap` function `_amountIn` parameter.
     */
    error CFMM_InsufficientAmountIn();

    /**
     * @dev Error indicates that calculated `amountOut` value in `swap`
     * function is not enough for the transfer.
     */
    error CFMM_InsufficientAmountOut();

    /**
     * @dev Error indicates that user provided not supported token address
     * in the `swap` function `_tokenIn` parameter.
     */
    error CFMM_UnsupportedTokenAddress();

    /**
     * @dev Error indicates that verification for ratio change in `addLiquidity`
     * function doesn't pass(ratio of tokens before adding liquidity != ratio 
     * of tokens after adding liquidity).
     */
    error CFMM_AssetsRatioCanNotBeChanged();

    /**
     * @dev Error indicates that after shares calculation in `addLiquidity` function,
     * the calculated amount is <= 0.
     */
    error CFMM_NotEnoughShares();

    /**
     * @dev Error indicates that after return amount calculation in `addLiquidity` function,
     * return amount for `amountA` and `amountB` is <= 0.
     */
    error CFMM_InsufficientLiquidityReturnAmount();
}
