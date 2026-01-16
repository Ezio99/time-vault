// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Vault} from "src/Vault.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract CodeConstants {
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant MAINNET_CHAIN_ID = 1;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
}

contract DeployVault is Script, CodeConstants {
    error DeployVault__ChainNotSupported();

    uint8 private constant DECIMALS = 8;
    int256 private constant INITIAL_ANSWER = 2000e8;

    mapping(uint256 chainId => address) public chainToPriceFeedMapping;

    constructor() {
        chainToPriceFeedMapping[SEPOLIA_CHAIN_ID] = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    }

    function deployLocalMock() public {
        vm.startBroadcast();
        MockV3Aggregator mock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        vm.stopBroadcast();
        chainToPriceFeedMapping[ANVIL_CHAIN_ID] = address(mock);
    }

    function deploy(uint256 chainId) public returns (Vault) {
        if (chainId == ANVIL_CHAIN_ID) {
            deployLocalMock();
        }

        if (chainToPriceFeedMapping[chainId] == address(0)) {
            revert DeployVault__ChainNotSupported();
        }

        vm.startBroadcast();
        Vault vault = new Vault(chainToPriceFeedMapping[chainId]);
        vm.stopBroadcast();
        return vault;
    }

    function run() external returns (Vault) {
        return deploy(block.chainid);
    }
}
