// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IHelper {
    struct NetworkConfig {
        address deployerAddress;
        uint256 deployerKey;
        string networkRPC;
    }
}
