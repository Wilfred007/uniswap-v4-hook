// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import { BaseHook } from "periphery-next/src/utils/BaseHook.sol";
import { ERC1155 } from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import { IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import { Hooks } from "v4-core/libraries/Hooks.sol";
import { PoolId, PoolIdLibrary } from "v4-core/libraries/PoolId.sol";
import { Currency, CurrencyLibrary } from "v4-core/libraries/CurrencyLibrary.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

//Libraries for calculating sqrtPriceLimitx96
import { TickMath } from "v4-core/libraries/TickMath.sol";
import { BalanceDelta } from "v4-core/types/BalanceDelta.sol";


contract TakeProfitHook is BaseHook, ERC1155 {
    using PoolIdLibrary for IpoolManager.PoolKey;
    using CurrencyLibrary for Currency;

    // Represent the last tickLower for each pool
    mapping(PoolId poolId => int24 tickLower) public tickLowerLast;

    //Represent the limit order for each pool
    // PoolId poolId => means the limit order is for a specific pool
    // mapping(int24 tick => means the limit order is for a specific tick
    // mapping(bool zeroForOne => means the limit order is for a specific direction with true being swapping token 0 for token 1 and false being swapping token 1 for token 0
    // int256 amount => means the limit order is for a specific amount
    mapping(
        PoolId poolId =>  
        mapping( int24 tick =>
        mapping( bool zeroForOne => 
            int256 amount 
        ))) public takeProfitPosition;


    // ERC-1155 - State
    //Mapping the store if a given token id(i.e a take profit order) exists
    mapping(uint256 tokenId => bool) public takeProfitExists;
    // Mapping to store how many swapped tokens are claimable for a given token id
    mapping(uint256 tokenId => uint256) public tokenIdClaimable;
    // Mapping that stores how many tokens need to be sold to execute the 
    mapping(uint256 tokenId => uint256 supply) public tokenIdTotalSupply;
    // Mapping that stores the PoolKey, tickLower and zeroForOne values for each token id
    mapping(uint256 tokenId => TokenData) public tokenIdData;

    // Initiallize base hook and ERC1155 parent contracts in the constructor
    constructor(
        IPoolManager _poolManager,
        string memory _url
    ) BaseHook(_poolManager) ERC1155(_url) {}

    //Required override function for basehook to let the pool managr know which hooks are implemented
    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return 
        Hooks.Calls({
            beforeInitialize: false,
            afterInitialize: true,
            beforeModifyPosition: false,
            afterModifyPosition: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
    }


    //Hooks
    function afterInitialize(address, IPoolManager.PoolKey calldata key, uint160, int24 tick) {
        _setTickLowerLast(key.toId(), getTickLower(tick, key.tickSpacing));

        // Every hook in uniswap v4 has to return a function selector
        return TakeProfitHook.affterInitialize.selector;
    }

    // Core utilities
    function placeOrder(
        IPoolManager.PoolKey calldata key,
        int24 tick,
        uint256 amountIn,
        bool zeroForOne
    ) external returns (int24){
        int24 tickLower = _getTickLower(tick, key.tickSpacing);

        takeProfitPosition[key.toId()][tickLower][zeroForOne] += amount;

        // Calculate the token ids for the recieved tokens
        uint256 tokenId = getTokenId(key, tickLower, zeroForOne);

        if(!tokenIdExists[tokenId]) {
            tokenIdExists[tokenId] = true;
            tokenIdData[tokenId] = TokenData(key, tickLower, zeroForOne);
        }

        _mint(msg.sender, tokenId, amountIn, "" );

        address tokenToBeSoldContract = zeroForOne ? 
        Currency.unwrap(key.currency0)
        : Currency.unwrap(key.currency1);

        IERC20(tokenToBeSoldContract).transferFrom(msg.sender, address(this), amountIn);

        return tickLower;
    }

    // Fill order function - this function executes orders, it is the function that after swap calls to execute orders
    function fillOrder(
        IPoolManager.PoolKey calldata key,
        int24 tick,
        bool zeroForOne,
        int256 amountIn
    ) internal {
        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountIn,
            // Set the price limit to be the least possible if swapping from token 0 to token 1
            // or the maximum possible if swapping from token 1 to token 0
            // i.e finite slippage allowed
            sqrtPriceLimitX96: zeroForOne
                ? TickMath.MIN_SQRT_RATIO + 1
                : TickMath.MAX_SQRT_RATIO - 1
        });

        BalanceDelta delta = abi.decode(  
            // In uniswap v4 you acquire a lock on the pool manager since there is a single contract that manages all the pools,
            // while you have a lock on the pool manager contract you can perform whatever action you want to perform on the pool
            // it can be swap, donate, modify position etc, then release the lock
            poolManager.lock(
                abi.encodeCall(this._handleSwap, (key, swapParams))
            ),
            (BalanceDelta)
        );
        takeProfitPositions[key.toId()][tick][zeroForOne] -= amountIn;

        uint256 tokenId = getTokenId(key, tick, zeroForOne);

    }

    // A helper function to execute swaps 
    function _handleSwap(
        IPoolManager.PoolKey calldata key,
        IPoolManager.SwapParams calldata params) external returns (BalanceDelta) {
            BalanceDelta delta = pollManager.swap(key, params); // Balance delta contains the exact amounts where amount 0 represents the delta change of token 0 and amount 1 reps the delta change of token 1

            /**When you call the swap function uniswap returns the delta change in balance
            For example you're swapping tokens 0 for token 1 you're increasing the balance of token 0 and 
            decreasing the balance ot token 1
              */

            if(params.zeroForOne){ // zeroForOne is true means we're swapping token 0 for token 1 (selling token 0 for token 1)
                if(delta.amount0() > 0) {
                    IERC20(Currency.unwrap(key.currency0)).transfer( //
                        address(poolManager),
                        uint128(delta.amount0())
                    );
                    poolManager.settle(key.currency0);
                }
                if(delta.amount1() < 0) {
                    poolManager.take(key.currency1, address(this), uint128(-delta.amount1()))
                }
            }else { // zeroForOne is false means we're swapping token 1 for token 0 (selling token 1 for token 0)
                if (delta.amount1() < 0) {
                    IERC20(Currency.unwrap(key.currency1)).transfer(
                        address(poolManager),
                        uint128(delta.amount1())
                    );
                    poolManager.settle(key.currency1);
                }
                if (delta.amount0 > 0) {
                    poolManager.take(key.currency0, address(this), uint128(-delta.amount0()));
                }
                
            }
            return delta;

        }


    function cancelOrder(IPoolManager.PoolKey calldata key, int24 tick, bool zeroForOne) external {
        int24 tickLower = _getTickLower(tick, key.tickSpacing);
        // get the token id for their order
        uint256 tokenId = getTokenId(key, tickLower, zeroForOne);

        // check how much balance of ERC1155 tokens they have
        uint256 amountIn = balanceOf(msg.sender, tokenId);  
        require(amount > 0, "No orders to cancel");

        // update the take profit position and reduce by amount in
        takeProfitPosition[key.toId()][tickLower][zeroForOne] -= int256(amountIn);

        //Reduce total supply for this token id by by the amount in
        tokenIdTotalSupply[tokenId] -= amountIn;

        // burn the ERC1155 tokens from the user
        _burn(msg.sender, tokenId, amountIn);

        // Take th contract address of the token they wish to sell and send it back to them
        address tokenToBeSoldContract = zeroForOne
            ? Currency.uniswap(key.currency0)
            : Currency.unwrap(key.currency1);

        IERC20(tokenToBeSoldContract).transfer(msg.sender, amountIn);
    }

    // ERC-1155 - helper function to get the unique token ID
    function getTokenId(
        IPoolManager.PoolKey calldata key,
        int24 tickLowe,
        bool zeroForOne
    ) public pure returns (uint256) {
        return 
        uint256(
            keccak256(abi.encode(key.toId(), tickLower, zeroForOne))
        );
    }



    // Helper functions
    function _setTickLowerLast(PoolId poolId, int24 tickLower) private {
        tickLowerLast[poolId] = tickLower;
    }

    function getTickLower(int24 actualTick, int24 tickSpacing) private pure returns (int24){
        int24 intervals = actualTick / tickSpacing;

        if(actualTick < 0 && (actualTick % tickSpacing != 0)){
            intervals--;
        }
        return intervals * tickSpacing;
    }


}