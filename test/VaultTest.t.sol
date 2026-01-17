// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {DeployVault, CodeConstants} from "script/DeployVault.s.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract VaultTest is Test {
    MockV3Aggregator mockV3Aggregator;
    Vault vault;

    address USER = makeAddr("user");

    function setUp() public {
        DeployVault deployer = new DeployVault();
        vault = deployer.deploy();
        mockV3Aggregator = MockV3Aggregator(address(vault.I_PRICE_FEED()));
        // Set an initial price (e.g., $2000 ETH/USD with 8 decimals)
        mockV3Aggregator.updateAnswer(2000e8);
        vm.deal(USER, 10 ether);
    }

    // function testSendLessMoney() public{
    //     uint256 amount = (vault.MIN_USD_PRICE_TO_STORE() * vault.getLatestEthToUsdPrice())-1e18;
    //     vm.expectRevert(Vault.Vault__NotEnoughEthSent.selector);
    //     vm.prank(USER);
    //     vault.deposit{value:amount}(vault.MIN_TIME_TO_LOCK());
    // }

    function testSendLessMoney() public {
        uint256 minUsd = vault.MIN_USD_PRICE_TO_STORE();
        uint256 price = vault.getLatestEthToUsdPrice();

        // 1. Calculate min ETH
        uint256 minEth = (minUsd * 1e18) / price;

        // 2. Subtract 1 Wei
        uint256 amountToSend = minEth - 1;
        uint256 time = vault.MIN_TIME_TO_LOCK();

        // --- DEBUG LOGS ---
        console2.log("Min USD (Contract):", minUsd); // Should be 5000000000000000000 (5e18)
        console2.log("Price (Contract):", price); // Should be 2000000000000000000000 (2000e18)
        console2.log("Calculated Min ETH:", minEth);
        console2.log("Sending Amount:", amountToSend);
        // ------------------

        vm.prank(USER);
        vm.expectRevert(Vault.Vault__NotEnoughEthSent.selector);
        vault.deposit{value: amountToSend}(time);
        console2.log("Hello");
    }
}
