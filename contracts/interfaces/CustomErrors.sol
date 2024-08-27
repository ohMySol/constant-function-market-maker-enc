// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface CfmmErrors {
    /**
     * @dev Error indicates that user provided not supported token address
     * in the `swap` function `_tokenIn` parameter.
     */
    error CFMM_UnsupportedTokenAddress();
}
