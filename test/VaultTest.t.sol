// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {DeployVault, CodeConstants} from "script/DeployVault.s.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract VaultTest is Test {
    event MoneyLocked(address indexed client, uint128 indexed balance, address indexed beneficiary, uint128 unlockTime);

    MockV3Aggregator mockV3Aggregator;
    Vault vault;

    uint256 public constant AMOUNT_TO_SEND = 0.5 ether;
    uint256 public constant DEAL_AMOUNT = 10 ether;

    address LOCKER_OWNER = makeAddr("vault_test_user_unique_123");
    address BENEFICARY = makeAddr("vault_test_beneficiary_unique_123");

    function setUp() public {
        DeployVault deployer = new DeployVault();
        vault = deployer.deploy();
        mockV3Aggregator = MockV3Aggregator(address(vault.I_PRICE_FEED()));
        // Set an initial price (e.g., $2000 ETH/USD with 8 decimals)
        // mockV3Aggregator.updateAnswer(2000e8);
        vm.deal(LOCKER_OWNER, DEAL_AMOUNT);
    }

    //MARK: Utility functions
    function depositMoney(
        uint256 _secondsToLockMoney,
        uint256 _amountToDeposit,
        address _lockerOwner,
        address _beneficiary
    ) public {
        vm.prank(_lockerOwner);
        vault.deposit{value: _amountToDeposit}(_secondsToLockMoney, _beneficiary);
    }

    function depositMoney(uint256 _secondsToLockMoney, uint256 _amountToDeposit) public {
        depositMoney(_secondsToLockMoney, _amountToDeposit, LOCKER_OWNER, BENEFICARY);
    }

    function depositMoney() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
    }

    function withdrawMoney(address _beneficiary, address _lockerOwner) public {
        vm.prank(_beneficiary);
        vault.withdraw(_lockerOwner);
    }

    function withdrawMoney() public {
        withdrawMoney(BENEFICARY, LOCKER_OWNER);
    }

    //MARK: Deposit

    function testDepositMoney() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        assertEq(vault.getLocker(LOCKER_OWNER, BENEFICARY).balance, AMOUNT_TO_SEND);
    }

    function testDepositLessMoney() public {
        uint256 minUsd = vault.MIN_USD_PRICE_TO_STORE();
        uint256 price = vault.getLatestEthToUsdPrice();

        // 1. Calculate min ETH
        uint256 minEth = (minUsd * 1e18) / price;

        // 2. Subtract 1 Wei
        uint256 amountToSend = minEth - 1;
        uint256 time = vault.MIN_TIME_TO_LOCK();

        vm.expectRevert(Vault.Vault__NotEnoughEthSent.selector);
        depositMoney(time, amountToSend);
    }

    function testDepositWithLessTime() public {
        uint256 time = vault.MIN_TIME_TO_LOCK() - 1;

        vm.prank(LOCKER_OWNER);
        vm.expectRevert(Vault.Vault__TooLittleTimeToLock.selector);
        vault.deposit{value: AMOUNT_TO_SEND}(time, BENEFICARY);
    }

    function testDepositWithMoreTime() public {
        uint256 time = vault.MAX_TIME_TO_LOCK() + 1;

        vm.prank(LOCKER_OWNER);
        vm.expectRevert(Vault.Vault__TooMuchTimeToLock.selector);
        vault.deposit{value: AMOUNT_TO_SEND}(time, BENEFICARY);
    }

    function testTopUpLocker() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);

        assertEq(vault.getLocker(LOCKER_OWNER, BENEFICARY).balance, AMOUNT_TO_SEND * 2);
    }

    function testTopUpLockerVariableTime() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        depositMoney(vault.MAX_TIME_TO_LOCK() - 1, AMOUNT_TO_SEND);

        assertEq(vault.getLocker(LOCKER_OWNER, BENEFICARY).balance, AMOUNT_TO_SEND * 2);
        assertEq(vault.getLocker(LOCKER_OWNER, BENEFICARY).unlockTime, block.timestamp + vault.MAX_TIME_TO_LOCK() - 1);
    }

    function testCannotShortenLockTime() public {
        uint256 longTime = 1000;
        depositMoney(longTime, AMOUNT_TO_SEND);
        uint256 initialUnlockTime = vault.getLocker(LOCKER_OWNER, BENEFICARY).unlockTime;

        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);

        uint256 finalUnlockTime = vault.getLocker(LOCKER_OWNER, BENEFICARY).unlockTime;
        assertEq(finalUnlockTime, initialUnlockTime);
    }

    //MARK: Withdraw
    function testSuccessfulWithdraw() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        assertEq(vault.getLocker(LOCKER_OWNER, BENEFICARY).balance, AMOUNT_TO_SEND);
        assertEq(LOCKER_OWNER.balance, DEAL_AMOUNT - AMOUNT_TO_SEND);

        vm.warp(vault.getLocker(LOCKER_OWNER, BENEFICARY).unlockTime + 1);
        withdrawMoney();
        assertEq(BENEFICARY.balance, AMOUNT_TO_SEND);
    }

    function testSuccessfulWithdrawToSelf() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND, LOCKER_OWNER, LOCKER_OWNER);
        assertEq(vault.getLocker(LOCKER_OWNER, LOCKER_OWNER).balance, AMOUNT_TO_SEND);
        assertEq(LOCKER_OWNER.balance, DEAL_AMOUNT - AMOUNT_TO_SEND);

        vm.warp(vault.getLocker(LOCKER_OWNER, LOCKER_OWNER).unlockTime + 1);
        withdrawMoney(LOCKER_OWNER, LOCKER_OWNER);
        assertEq(LOCKER_OWNER.balance, DEAL_AMOUNT);
    }

    function testWithdrawNoLockerPresent() public {
        vm.expectRevert(Vault.Vault__NoLocker.selector);
        withdrawMoney();
    }

    function testWithdrawBeforeTime() public {
        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
        assertEq(vault.getLocker(LOCKER_OWNER, BENEFICARY).balance, AMOUNT_TO_SEND);
        assertEq(LOCKER_OWNER.balance, DEAL_AMOUNT - AMOUNT_TO_SEND);

        vm.expectRevert(Vault.Vault__NotUnlockTime.selector);
        withdrawMoney();
    }

    function testMultipleDepositorsForSameBeneficiary() public {
        address DAD = makeAddr("dad");
        address MOM = makeAddr("mom");

        uint256 time = vault.MIN_TIME_TO_LOCK();

        // 1. Dad deposits for Beneficiary
        vm.deal(DAD, 1 ether);
        vm.prank(DAD);
        vault.deposit{value: 1 ether}(time, BENEFICARY);

        // 2. Mom deposits for SAME Beneficiary
        vm.deal(MOM, 1 ether);
        vm.prank(MOM);
        vault.deposit{value: 1 ether}(time, BENEFICARY);

        // 3. Verify Beneficiary has TWO separate lockers
        uint128 dadBalance = vault.getLocker(DAD, BENEFICARY).balance;
        uint128 momBalance = vault.getLocker(MOM, BENEFICARY).balance;

        assertEq(dadBalance, 1 ether);
        assertEq(momBalance, 1 ether);
    }

    function testOneDepositorManyBeneficiaries() public {
        address UNCLE = makeAddr("uncle");
        address NEPHEW_A = makeAddr("nephewA");
        address NEPHEW_B = makeAddr("nephewB");

        uint256 amountA = 1 ether;
        uint256 amountB = 2 ether;
        uint256 minTime = vault.MIN_TIME_TO_LOCK();

        vm.deal(UNCLE, 10 ether);

        // 1. Uncle deposits for Nephew A
        vm.prank(UNCLE);
        vault.deposit{value: amountA}(minTime, NEPHEW_A);

        // 2. Uncle deposits for Nephew B
        vm.prank(UNCLE);
        vault.deposit{value: amountB}(minTime, NEPHEW_B);

        // 3. Verify Separation
        uint128 balA = vault.getLocker(UNCLE, NEPHEW_A).balance;
        uint128 balB = vault.getLocker(UNCLE, NEPHEW_B).balance;

        assertEq(balA, amountA);
        assertEq(balB, amountB);
    }

    function testDifferentUnlockTimesForDifferentBeneficiaries() public {
        address DAD = makeAddr("dad");
        address SON = makeAddr("son");
        address DAUGHTER = makeAddr("daughter");

        uint256 shortTime = vault.MIN_TIME_TO_LOCK(); // 60 seconds
        uint256 longTime = vault.MIN_TIME_TO_LOCK() * 10; // 600 seconds

        vm.deal(DAD, 10 ether);

        // 1. Dad locks for Son (Short)
        vm.prank(DAD);
        vault.deposit{value: 1 ether}(shortTime, SON);

        // 2. Dad locks for Daughter (Long)
        vm.prank(DAD);
        vault.deposit{value: 1 ether}(longTime, DAUGHTER);

        // 3. Fast forward past Son's time but BEFORE Daughter's time
        vm.warp(block.timestamp + shortTime + 1);

        // 4. Son should succeed
        vm.prank(SON);
        vault.withdraw(DAD);
        assertEq(SON.balance, 1 ether);

        // 5. Daughter should FAIL (Too early)
        vm.prank(DAUGHTER);
        vm.expectRevert(Vault.Vault__NotUnlockTime.selector);
        vault.withdraw(DAD);
    }

    function testWithdrawFromWrongDepositorFails() public {
        address ALICE = makeAddr("alice");
        address BOB = makeAddr("bob"); // Alice deposits for Bob
        address CHARLIE = makeAddr("charlie"); // Charlie did NOT deposit for Bob

        uint256 minTime = vault.MIN_TIME_TO_LOCK();

        // 1. Alice funds Bob
        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        vault.deposit{value: 1 ether}(minTime, BOB);

        // 2. Bob tries to claim money from Charlie (who never sent him anything)
        vm.warp(block.timestamp + minTime + 1);

        vm.prank(BOB);
        vm.expectRevert(Vault.Vault__NoLocker.selector);
        vault.withdraw(CHARLIE);
    }

    function testFuzzDeposit(uint256 amount, uint256 time) public {
        amount = bound(amount, 0.1 ether, 100_000 ether);

        time = bound(time, vault.MIN_TIME_TO_LOCK(), vault.MAX_TIME_TO_LOCK());

        vm.deal(LOCKER_OWNER, amount);
        vm.prank(LOCKER_OWNER);

        vault.deposit{value: amount}(time, BENEFICARY);

        assertEq(vault.getLocker(LOCKER_OWNER, BENEFICARY).balance, amount);
    }

    function testRevertIfPriceIsNegative() public skipWhenForking {
        mockV3Aggregator.updateAnswer(-100);
        uint256 time = vault.MIN_TIME_TO_LOCK();

        vm.prank(LOCKER_OWNER);
        vm.expectRevert(Vault.Vault__PriceIsNegative.selector);

        vault.deposit{value: AMOUNT_TO_SEND}(time, BENEFICARY);
    }

    //MARK: Events
    function testEmitMoneyLockedEvent() public {
        vm.expectEmit(true, true, true, true, address(vault));

        uint128 expectedUnlock = uint128(block.timestamp + vault.MIN_TIME_TO_LOCK());
        emit MoneyLocked(LOCKER_OWNER, uint128(AMOUNT_TO_SEND), BENEFICARY, expectedUnlock);

        depositMoney(vault.MIN_TIME_TO_LOCK(), AMOUNT_TO_SEND);
    }
}
