// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import { BaseHook } from "periphery-next/BaseHook.sol";
import { ERC1155 } from "open-zeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import { IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import { Hooks } from "v4-core/libraries/Hooks.sol";


contract TakeProfitHook is BaseHook, ERC1155 {
    
}