## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
 # ticks
 SOlidity does not support floating-point numbers.
 Ticks - represent token prices of a pair of tokens in a pool.

 Conceptually - The smallest amount possible by which the proce of an asset can move up or down.
 
 Ticks are spaced at intervals of tickSpacing

 We round the actual tick to either `tickLower` or `tickUpper` 0 and 1 respectively


 `tickLower` is the lower bound of the price range
 `tickUpper` is the upper bound of the price range

 # sqrtPriceLimitx96
 This is also used to keep track of prices  - since soldity does not support floating point numbers. complex measures are used to represent precise prices

 # Q notation 
 This is used to convert a number from its Q notation (Q128.128) to a decimal number and vice versa
 Example some value v that is in decimal
 v = Q notation
 V * (2 ^ k) where k = some constant 
 and k depends on how big of a Q notation we are using