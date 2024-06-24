// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IHelper} from "./IHelper.sol";
import {ZeroDay} from "../src/ZeroDay.sol";

contract ZeroDayDeployement is Script, IHelper {
    HelperConfig public helper;
    NetworkConfig public config;

    ZeroDay public collection;

    // @audit THESE VALUES ARE NOT VALID, CHANGE THEM BEFORE DEPLOYING ON MAINNET.//////////////////
    uint32 public constant start_pre_sale_date_example = 1718203812; // Wednesday, June 12, 2024 2:50:12 PM
    uint32 public constant start_reveal_date_example = 1720795812; // Friday, July 12, 2024 2:50:12 PM
    uint32 public constant start_public_sale_date_example = 1723474212; // Monday, August 12, 2024 2:50:12 PM
    bytes32 public merkleRoot;
    //////////////////////////////////////// INVALID VALUES ////////////////////////////////////////
    
    function run() public {
        // merkleRoot = keccak256(abi.encodePacked("merkleRoot"));
        merkleRoot = 0x3ef3c37222a4ae25c73bbf9074ed6bca833ca17ab10d3ea209fa3a316598e31b;
        bool onTestnet = true;

        vm.chainId(11155111); // ETH Mainnet chainId
        // vm.chainId(1);

        helper = new HelperConfig(onTestnet);
        config = helper.getConfig();

        vm.startBroadcast(config.deployerKey);
        collection = new ZeroDay(
            start_pre_sale_date_example,
            start_reveal_date_example,
            start_public_sale_date_example,
            merkleRoot
        );
        vm.stopBroadcast();

        console.logAddress(address(collection));
    }
}
