// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {DeployVault, CodeConstants} from "script/DeployVault.s.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract VaultTest is Test {
    event MoneyLocked(address indexed client, uint128 indexed balance, uint128 indexed unlockTime);


    MockV3Aggregator mockV3Aggregator;
    Vault vault;

    uint256 public constant AMOUNT_TO_SEND = 0.5 ether;
    uint256 public constant DEAL_AMOUNT = 10 ether;

    address USER = makeAddr("user");

    function setUp() public {
        DeployVault deployer = new DeployVault();
        vault = deployer.deploy();
        mockV3Aggregator = MockV3Aggregator(address(vault.I_PRICE_FEED()));
        // Set an initial price (e.g., $2000 ETH/USD with 8 decimals)
        mockV3Aggregator.updateAnswer(2000e8);
        vm.deal(USER, DEAL_AMOUNT);
    }

    //MARK: Utility functions
    function depositMoney(uint256 _secondsToLockMoney, uint256 _amountToDeposit) public {
        vm.prank(USER);
        vault.deposit{value: _amountToDeposit}(_secondsToLockMoney);
    }

    function withdrawMoney() public {
        vm.prank(USER);
        vault.withdraw();
    }

    //MARK: Deposit

    function testDepositMoney() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        assertEq(vault.getLocker(USER).balance, AMOUNT_TO_SEND);
    }

    function testDepositLessMoney() public {
        uint256 minUsd = vault.MIN_USD_PRICE_TO_STORE();
        uint256 price = vault.getLatestEthToUsdPrice();

        // 1. Calculate min ETH
        uint256 minEth = (minUsd * 1e18) / price;

        // 2. Subtract 1 Wei
        uint256 amountToSend = minEth - 1;
        uint256 time = vault.MIN_TIME_TO_LOCK();

        vm.prank(USER);
        vm.expectRevert(Vault.Vault__NotEnoughEthSent.selector);
        vault.deposit{value: amountToSend}(time);
    }

    function testDepositWithLessTime() public {
        uint256 time = vault.MIN_TIME_TO_LOCK() - 1;

        vm.prank(USER);
        vm.expectRevert(Vault.Vault__TooLittleTimeToLock.selector);
        vault.deposit{value: AMOUNT_TO_SEND}(time);
    }

    function testDepositWithMoreTime() public {
        uint256 time = vault.MAX_TIME_TO_LOCK() + 1;

        vm.prank(USER);
        vm.expectRevert(Vault.Vault__TooMuchTimeToLock.selector);
        vault.deposit{value: AMOUNT_TO_SEND}(time);
    }

    function testTopUpLocker() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);

        assertEq(vault.getLocker(USER).balance, AMOUNT_TO_SEND * 2);
    }

    function testTopUpLockerVariableTime() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        depositMoney(vault.MAX_TIME_TO_LOCK() - 1, AMOUNT_TO_SEND);

        assertEq(vault.getLocker(USER).balance, AMOUNT_TO_SEND * 2);
        assertEq(vault.getLocker(USER).unlockTime, vault.MAX_TIME_TO_LOCK());
    }

       function testCannotShortenLockTime() public {
        uint256 longTime = 1000;
        depositMoney(longTime, AMOUNT_TO_SEND);
        uint256 initialUnlockTime = vault.getLocker(USER).unlockTime;

        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);

        uint256 finalUnlockTime = vault.getLocker(USER).unlockTime;
        assertEq(finalUnlockTime, initialUnlockTime); 
    }

    //MARK: Withdraw
    function testSuccessfulWithdraw() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        assertEq(vault.getLocker(USER).balance, AMOUNT_TO_SEND);
        assertEq(USER.balance, DEAL_AMOUNT - AMOUNT_TO_SEND);

        vm.warp(vault.MIN_TIME_TO_LOCK() + 1);
        withdrawMoney();
        assertEq(USER.balance, DEAL_AMOUNT);
    }

    function testWithdrawNoLockerPresent() public {
        vm.expectRevert(Vault.Vault__NoLocker.selector);
        withdrawMoney();
    }

    function testWithdrawBeforeTime() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        assertEq(vault.getLocker(USER).balance, AMOUNT_TO_SEND);
        assertEq(USER.balance, DEAL_AMOUNT - AMOUNT_TO_SEND);

        vm.expectRevert(Vault.Vault__NotUnlockTime.selector);
        withdrawMoney();
    }

    function testFuzzDeposit(uint256 amount, uint256 time) public {
        amount = bound(amount, 0.1 ether, 100_000 ether); 
        
        
        time = bound(time, vault.MIN_TIME_TO_LOCK(), vault.MAX_TIME_TO_LOCK());

        vm.deal(USER, amount);
        vm.prank(USER);
        
        vault.deposit{value: amount}(time);

        
        assertEq(vault.getLocker(USER).balance, amount);
    }


    function testRevertIfPriceIsNegative() public {
        
        mockV3Aggregator.updateAnswer(-100); 
        uint256 time = vault.MIN_TIME_TO_LOCK();

        
        vm.prank(USER);
        vm.expectRevert(Vault.Vault__PriceIsNegative.selector);
        
        
        vault.deposit{value: AMOUNT_TO_SEND}(time);
    }

    //MARK: Events
    function testEmitMoneyLockedEvent() public {
        vm.expectEmit(true, true, true, false); 
        
        uint128 expectedUnlock = uint128(block.timestamp + vault.MIN_TIME_TO_LOCK());
        emit MoneyLocked(USER, uint128(AMOUNT_TO_SEND), expectedUnlock);

        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
    }

 
}
