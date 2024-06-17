// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IHelper} from "./IHelper.sol";

error HelperConfig__NotInvalidChainId(uint256 chainid);

contract HelperConfig is Script, IHelper {
    NetworkConfig private config;

    constructor(bool testnet) {
        if (testnet) {
            if (block.chainid == 11155111) {
                config = getSepoliaETHNetworkConfig();
            } else if (block.chainid == 0x8274f) {
                config = getSepoliaScrollNetworkConfig();
            } else if (block.chainid == 0xa0c71fd) {
                config = getSepoliaBlastNetworkConfig();
            } else {
                config = getAnvilNetworkConfig();
            }
        } else {
            if (block.chainid == 1) {
                console.log("Now we are on ETH mainnet network!");
                config = getETHMainnetNetworkConfig();
            } else if (block.chainid == 0x82750) {
                console.log("Now we are on Scroll mainnet network!");
                config = getScrollMainnetNetworkConfig();
            } else if (block.chainid == 0xee) {
                console.log("Now we are on Blast mainnet network!");
                config = getBlastMainnetNetworkConfig();
            } else {
                revert HelperConfig__NotInvalidChainId(block.chainid);
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            TESTNET CONFIG
    //////////////////////////////////////////////////////////////*/
    function getSepoliaETHNetworkConfig() public view returns (NetworkConfig memory conf) {
        conf = NetworkConfig({
            deployerAddress: 0xcec782b7497Bc30CADCeA73aC53a8f9DB2aD7dc5,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            networkRPC: vm.envString("ALCHEMY_ENDPOINT")
        });
        console.log("We are now on Etehreum Sepolia test network!");
    }

    function getSepoliaScrollNetworkConfig() public view returns (NetworkConfig memory conf) {
        conf = NetworkConfig({
            deployerAddress: 0xcec782b7497Bc30CADCeA73aC53a8f9DB2aD7dc5,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            networkRPC: vm.envString("SCROLL_SEPOLIA_NETWORK")
        });
        console.log("We are now on Scroll Sepolia test network!");
    }

    function getSepoliaBlastNetworkConfig() public view returns (NetworkConfig memory conf) {
        conf = NetworkConfig({
            deployerAddress: 0xcec782b7497Bc30CADCeA73aC53a8f9DB2aD7dc5,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            networkRPC: vm.envString("BLAST_SEPOLIA_RPC")
        });
        console.log("We are now on Blast Sepolia test network!");
    }

    function getAnvilNetworkConfig() public view returns (NetworkConfig memory conf) {
        conf = NetworkConfig({
            deployerAddress: 0xcec782b7497Bc30CADCeA73aC53a8f9DB2aD7dc5,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            networkRPC: vm.envString("")
        });
        console.log("We are now on Anvil local network!");
    }

    /*///////////////////////////////////////////////////////////////
                            MAINNET CONFIGS
    //////////////////////////////////////////////////////////////*/
    function getETHMainnetNetworkConfig() public view returns (NetworkConfig memory conf) {
        conf = NetworkConfig({
            deployerAddress: 0xcec782b7497Bc30CADCeA73aC53a8f9DB2aD7dc5,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            networkRPC: vm.envString("ETHEREUM_MAINNET_NETWORK_RPC")
        });
        console.log("We are now on Etehreum Mainnet test network!");
    }

    function getScrollMainnetNetworkConfig() public view returns (NetworkConfig memory conf) {
        conf = NetworkConfig({
            deployerAddress: 0xcec782b7497Bc30CADCeA73aC53a8f9DB2aD7dc5,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            networkRPC: vm.envString("SCROLL_MAINNET_NETWORK_RPC")
        });
        console.log("We are now on Scroll Mainnet network!");
    }

    function getBlastMainnetNetworkConfig() public view returns (NetworkConfig memory conf) {
        conf = NetworkConfig({
            deployerAddress: 0xcec782b7497Bc30CADCeA73aC53a8f9DB2aD7dc5,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            networkRPC: vm.envString("BLAST_MAINNET_NETWORK_RPC")
        });
        console.log("We are now on Blast Mainnet network!");
    }

    function getConfig() public view returns (NetworkConfig memory confResult) {
        confResult = config;
    }
}
