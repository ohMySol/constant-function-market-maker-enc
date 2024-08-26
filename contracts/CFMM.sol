// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "fhevm/lib/TFHE.sol";
import "./interfaces/IERC20.sol";
import "fhevm/gateway/GatewayCaller.sol";
import {CfmmErrors} from "./interfaces/CustomErrors.sol";
contract CFMM is CfmmErrors {
    event ErrorChanged(address sender);
    
    IERC20 public immutable TOKEN_A;
    IERC20 public immutable TOKEN_B;
    struct LastError {
        euint8 error;
        uint256 timestamp;
    }
    // Declare Errors
    euint8 internal NO_ERROR;
    euint8 internal INSUFFICIENT_AMOUNT_IN;
    euint8 internal INSUFFICIENT_AMOUNT_OUT;
    euint8 internal UNSUPPORTED_TOKEN_ADDRESS;
    euint8 internal ASSETS_RATIO_WAS_CHANGED;
    euint8 internal NOT_ENOUGH_LIQUIDITY_TO_ADD;
    euint8 internal NOT_ENOUGH_LIQUIDITY_TO_BURN;

    // Pool reserves and totalSharesSupply
    uint64 public reserveA;
    uint64 public reserveB;
    uint64 public totalSharesSupply;
    // Store for each `address` a `euint64` share balance.
    mapping(address => euint64) public shareBalance;
    // Store for each `address` the latest `LastError` error.
    mapping(address => LastError) public latestError;

    constructor(address _tokenA, address _tokenB) {
        TOKEN_A = IERC20(_tokenA);
        TOKEN_B= IERC20(_tokenB);
        NO_ERROR = TFHE.asEuint8(0);
        INSUFFICIENT_AMOUNT_IN = TFHE.asEuint8(1);
        INSUFFICIENT_AMOUNT_OUT = TFHE.asEuint8(2);
        UNSUPPORTED_TOKEN_ADDRESS = TFHE.asEuint8(3);
        ASSETS_RATIO_WAS_CHANGED = TFHE.asEuint8(4);
        NOT_ENOUGH_LIQUIDITY_TO_ADD = TFHE.asEuint8(5);
        NOT_ENOUGH_LIQUIDITY_TO_BURN = TFHE.asEuint8(6);
    }

    /**
     * ! Function is not working, because I am got stuck with the TFHE.div() which
     * is using a plain text divisor.
     * @notice User can swap his `tokenA` for `tokenB` or vice versa.
     * @dev 1. Function takes `_tokenIn` prameter, and set up the `tokenIn` and 
     * `tokenOut` tokens.
     * 2. User send `tokenIn` tokens to CFMM contract, and swap function calculates 
     * the `amountOut` value that user will receive back. 
     * 3. Each swap takes 0.3% fee from `_amountIn` value. 
     * @param _tokenIn - address of the token for sell.
     * @param _amountIn - amount of tokens user want to sell. 
     */
    function swap(address _tokenIn, uint256 _amountIn) external returns (euint64 amountOut) {
        if(_tokenIn != address(TOKEN_A) && _tokenIn != address(TOKEN_B)) {
            revert CFMM_UnsupportedTokenAddress();
        }
        euint64 amountIn = TFHE.asEuint64(_amountIn);
        ebool amountInLessThanZero = TFHE.lt(amountIn, 0);
        _setLastError(TFHE.select(amountInLessThanZero, INSUFFICIENT_AMOUNT_IN, NO_ERROR), msg.sender);
        (
            IERC20 tokenIn, 
            IERC20 tokenOut, 
            uint256 reserveIn, 
            uint256 reserveOut
        ) = _setInOutToken(_tokenIn);
        euint64 _reserveIn = TFHE.asEuint64(reserveIn);
        euint64 _reserveOut = TFHE.asEuint64(reserveIn);

        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        // 2. Calculate amount of tokens out(include fees), fee 0.3%
        euint64 amountInAfterFee = TFHE.div(TFHE.mul(amountIn, 997), 1000);
        // Formula how much tokens to return: y * dx / (x + dx) = dy 
        amountOut = TFHE.div(TFHE.mul(_reserveOut, amountInAfterFee), TFHE.add(_reserveIn, amountInAfterFee)); // Error is here in TFHE.div()
        // 3. Transfer calculated tokenout amount to msg.sender
        bool amountOutLessThanZero = TFHE.lt(amountOut, 0);
        _setLastError(TFHE.select(amountOutLessThanZero, INSUFFICIENT_AMOUNT_OUT, NO_ERROR), msg.sender);
        tokenOut.transfer(msg.sender, amountOut);
        // 4. Upd reserves
        euint64 balanceA = TOKEN_A.balanceOf(address(this));
        euint64 balanceB = TOKEN_A.balanceOf(address(this));
        _updateReserves(balanceA, balanceB); 
    }

    /**
     * ! Function is not working, because I am got stuck with the division. Becasue it is using a 
     * plain text divisor I can't devide for encrypted value, as a result I can't convert reserves
     * to encrypted value.
     * @notice Users(future LPs) can add liquidity of the token pair in the liquidity pool,
     * and earn fees.
     * @dev Function takes `_amountA` and `_amountB` arguments, then fund a pool with them.
     * Calculates the amount of `shares` to be minted to `msg.sender` and mint them. And in
     * the end update reserves of `tokenA` and `tokenB` in the contract with new balances.
     */
    function addLiquidity(uint256 _amountA, uint256 _amountB) external returns (euint64 shares) {
        euint64 amountA = TFHE.asEuint64(_amountA);
        euint64 amountB = TFHE.asEuint64(_amountB);
        TFHE.allow(amountA, address(this));
        TFHE.allow(amountB, address(this));

        if (reserveA > 0 || reserveB > 0) {
            // Check that ratio for tokens remains the same by applying formula((dx/dy )= (x/y)) or ((dy*x )==(dx*y))
            ebool isRatioChanged = TFHE.ne(
                TFHE.mul(amountB, TFHE.asEuint64(reserveA)), 
                TFHE.mul(amountA, TFHE.asEuint64(reserveB))
            );
            _setLastError(TFHE.select(isRatioChanged, NO_ERROR, ASSETS_RATIO_WAS_CHANGED), msg.sender);
        }
        // Fund pool with tokenA & tokenB
        TOKEN_A.transferFrom(msg.sender, address(this), amountA);
        TOKEN_B.transferFrom(msg.sender, address(this), amountB);
        euint64 balanceA = TOKEN_A.balanceOf(address(this));
        euint64 balanceB = TOKEN_B.balanceOf(address(this));
        euint64 _totalSharesSupply = totalSharesSupply;
        // Mint LP tokens(shares)
        // Formulas: 
        // 1. Total liquidity = f(x, y) = sqrt(x, y)
        // 2. Shares to mint = dx / x * T = dy / y * T 
        ebool liquidityExist = TFHE.eq(_totalSharesSupply, 0);
        euint64 sqrtShares = _sqrt(TFHE.mul(amountA, amountB)); // if liquidity doesn't exist
        euint64 calcShares = TFHE.min( // if liquidity exist
           TFHE.div(TFHE.mul(amountA, _totalSharesSupply), reserveA),
           TFHE.div(TFHE.mul(amountB, _totalSharesSupply), reserveB)
        );
        shares = TFHE.select(liquidityExist, calcShares, sqrtShares); // make sure calculated shares > 0
        ebool isEnoughLiquidityAdded =  TFHE.gt(shares, 0);
        _setLastError(TFHE.select(isEnoughLiquidityAdded, NO_ERROR, NOT_ENOUGH_LIQUIDITY_TO_ADD), msg.sender);
        _mintShares(msg.sender, shares);
        _updateReserves(balanceA, balanceB);
    }

    /**
     * ! Function is not working, because I am got stuck again with the _updateReserves() function. 
     * Becasue it is using a plain text uint64, but I am applying euint64, and this function is used in
     * several functions, so I can't easily change the type and finish with this.
     * @notice LPs can call this function to return their tokens from a liquidity pool,
     * plus earned fees. 
     * @dev Function calculates the returned amount of `amountA` tokens and `amountB` 
     * tokens based on the LP `_shares` and  `totalSharesSupply`. Then burn `_shares`,
     * update reserves with new balances and transfer `amountA` and `amountB` to `msg.sender`.
     */
    function withdrawLiquidity(euint64 _shares) external returns (euint64 amountA, euint64 amountB) {
        // Calculate the amountA and amountB of tokens for withdraw(should be proportional to shares)
        // Formulas: 1. dx = s / T * x
        // 2. dy = s / T * y
        uint64 _totalSharesSupply = totalSharesSupply;
        euint64 balanceA = TOKEN_A.balanceOf(address(this));
        euint64 balanceB = TOKEN_B.balanceOf(address(this));
        amountA = TFHE.div(TFHE.mul(balanceA, _shares), _totalSharesSupply);
        amountB = TFHE.div(TFHE.mul(balanceB, _shares), _totalSharesSupply);
        ebool ifAmountALt0 = TFHE.lt(amountA, 0);
        ebool ifAmountBLt0 = TFHE.lt(amountB, 0);
        _setLastError(TFHE.select(ifAmountALt0, NO_ERROR, NOT_ENOUGH_LIQUIDITY_TO_ADD), msg.sender);
        _setLastError(TFHE.select(ifAmountBLt0, NO_ERROR, NOT_ENOUGH_LIQUIDITY_TO_ADD), msg.sender);
        // Burn shares
        _burnShares(msg.sender, _shares);
        // Update reservs
        _updateReserves(balanceA - amountA, balanceB - amountB);
        // Transfer tokens to msg.sender
        TOKEN_A.transfer(msg.sender, amountA);
        TOKEN_B.transfer(msg.sender, amountB);
    }

    /**
     * ! Function doesn't work at the moment, becasue I am got stuck with the type
     * casting for reserves.
     * @dev Fucntion updates `reserveA` and `reserveB` for a specified amounts:
     * `_newReserveA` and `_newReserveB`
     * @param _newReserveA - updated `tokenA` tokens amount in the contract.
     * @param _newReserveB  - updated `tokenb` tokens amount in the contract.
     */
    function _updateReserves(uint64 _newReserveA, uint64 _newReserveB) private {
        reserveA = _newReserveA;
        reserveB = _newReserveB;
    }

    /**
     * ! Function doesn't work at the moment, because I am got stuck with 'totalSharesSupply'.
     * If I change the type in one place, then in other place it will throw me an error.
     * @dev Function mints a specified `_amount` of shares to `_to` address,
     * when LP add a liquidity to a pool.
     * @param _to - address of the LP, who receive minted shares.
     * @param _amount - amount to mint.
     */
    function _mintShares(address _to, euint64 _amount) private {
        shareBalance[_to] = TFHE.add(shareBalance[_to], _amount);
        totalSharesSupply = TFHE.add(totalSharesSupply, _amount);
    }

    /**
     * ! Function is not working, because I am got stuck with 'totalSharesSupply'.
     * If I change the type in one place, then in other place it will throw me an error.
     * @dev Function burn a specified `_amount` of shares from `_from` address,
     * when LP remove liquidity from a pool.
     * @param _from - address of the LP, who receive minted shares.
     * @param _amount - amount to mint.
     */
    function _burnShares(address _from, euint64 _amount) private {
        shareBalance[_from] = TFHE.sub(shareBalance[_from], _amount);
        totalSharesSupply = TFHE.sub(totalSharesSupply, _amount);
    }

    /**
     * @dev Returns LP `euint64` amount of shares.
     */
    function getShares() public view returns (euint64) {
        return shareBalance[msg.sender]; 
    }

    /**
     * @dev Returns a `reserveA` and `reserveB` values.
     */
    function getReserves() public view returns (uint256 _reserveA, uint256 _reserveB) {
        (_reserveA, _reserveB) = (reserveA, reserveB);
    }

    /**
     * @dev Function set up In and Out tokens for a swap. If `_tokenIn` is an `tokenA`,
     * then return a tuple (`tokenIn` = `tokenA`, `tokenOut` = `tokenB`), and vise versa
     * if `_tokenIn` is a `tokenB`.
     * @param _tokenIn - address of the token for sell.
     */
    function _setInOutToken(address _tokenIn) private view returns (
        IERC20 tokenIn, 
        IERC20 tokenOut, 
        uint256 reserveIn,
        uint256 reserveOut
    )
    {
        bool isTokenA = _tokenIn == address(TOKEN_A);
        (tokenIn, tokenOut, reserveIn, reserveOut) = isTokenA
            ? (TOKEN_A, TOKEN_B, reserveA, reserveB)
            : (TOKEN_B, TOKEN_A, reserveB, reserveA);
    }

    /**
     * @dev Helper function. Returns square root from provided `y` argument.
     * @param y - uint256 value.
     */
    function _sqrt(euint64 y) private pure returns (euint64 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _setLastError(euint8 error, address addr) private {
        latestError[addr] = LastError(error, block.timestamp);
        emit ErrorChanged(addr);
    }
    
}
