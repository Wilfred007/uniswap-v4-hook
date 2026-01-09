// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import { BaseHook } from "periphery-next/src/utils/BaseHook.sol";
import { ERC1155 } from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import { IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import { Hooks } from "v4-core/libraries/Hooks.sol";
import { PoolId, PoolIdLibrary } from "v4-core/libraries/PoolId.sol";
import { Currency, CurrencyLibrary } from "v4-core/libraries/CurrencyLibrary.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


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
        uint256 amount,
        bool zeroForOne
    ) external returns (int24){
        int24 tickLower = _getTickLower(tick, key.tickSpacing);

        
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