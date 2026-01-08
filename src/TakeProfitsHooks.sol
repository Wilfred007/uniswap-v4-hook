// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import { BaseHook } from "periphery-next/src/utils/BaseHook.sol";
import { ERC1155 } from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import { IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import { Hooks } from "v4-core/libraries/Hooks.sol";
import { PoolId, PoolIdLibrary } from "v4-core/libraries/PoolId.sol";


contract TakeProfitHook is BaseHook, ERC1155 {
    using PoolIdLibrary for IpoolManager.PoolKey;

    // Represent the last tickLower for each pool
    mapping(PoolId poolId => int24 tickLower) public tickLowerLast;

    //Represent the limit order for each pool
    // PoolId poolId => means the limit order is for a specific pool
    // int24 tick => means the limit order is for a specific tick
    mapping(
        PoolId poolId =>  
        mapping( int24 tick => )
    )
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
        })
    }
}