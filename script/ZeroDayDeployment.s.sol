// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import { console } from "forge-std/console.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { IHelper } from "./IHelper.sol";
import { ZeroDay } from "../src/ZeroDay.sol";


contract ZeroDayDeployement is Script, IHelper {
    HelperConfig public helper;
    NetworkConfig public config;
    
    ZeroDay public collection;

    // @audit THESE VALUES ARE NOT VALID, CHANGE THEM BEFORE DEPLOYING ON MAINNET.//////////////////
    uint256 public constant init_pre_sale_price_example = 1 ether;
    uint256 public constant start_pre_sale_date_example = 1716718200; // Sunday, May 26, 2024 10:10:00 AM
    uint256 public constant start_reveal_date_example = 1716977400; // Wednesday, May 29, 2024 10:10:00 AM
    uint256 public constant start_public_sale_date_example =  1717063800; //Thursday, May 30, 2024 10:10:00 AM
    bytes32 public merkleRoot;
    //////////////////////////////////////// INVALID VALUES ////////////////////////////////////////

    function run() public {
        merkleRoot = keccak256(abi.encodePacked("merkleRoot"));
        bool onTestnet = true;

        vm.chainId(111555111); // ETH sepolia chainid

        helper = new HelperConfig(onTestnet);
        config = helper.getConfig();

        vm.startBroadcast(config.deployerKey);
        collection = new ZeroDay(
            init_pre_sale_price_example,
            start_pre_sale_date_example,
            start_reveal_date_example,
            start_public_sale_date_example,
            merkleRoot
        );
        vm.stopBroadcast();

        console.logAddress(address(collection));
    }
}
