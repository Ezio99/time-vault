// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Vault {
    error Vault__PriceIsNegative();
    error Vault__NotEnoughEthSent();
    error Vault__TooMuchTimeToLock();
    error Vault__TooLittleTimeToLock();


    event MoneyLocked(address indexed client,uint128 indexed balance,uint128 indexed unlockTime);

    struct Locker {
        uint128 balance;
        uint128 unlockTime;
    }

    mapping(address => Locker) sBalances;
    address private immutable iOwner;
    AggregatorV3Interface private immutable iPriceFeed;

    uint256 private constant MIN_USD_PRICE_TO_STORE = 5 * 1e18;
    uint256 private constant MIN_TIME_TO_LOCK = 60;
    uint256 private constant MAX_TIME_TO_LOCK = 60 * 60 * 24 * 365 * 10;

    constructor(address priceFeedAddress) {
        iOwner = msg.sender;
        iPriceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    function deposit(uint256 _secondsToLockMoney) external payable {
        if (_secondsToLockMoney < MIN_TIME_TO_LOCK) {
            revert Vault__TooLittleTimeToLock();
        }

        if (_secondsToLockMoney > MAX_TIME_TO_LOCK) {
            revert Vault__TooMuchTimeToLock();
        }

        if (getUSDPrice(msg.value) < MIN_USD_PRICE_TO_STORE) {
            revert Vault__NotEnoughEthSent();
        }

        Locker storage locker = sBalances[msg.sender];

        uint128 unlockTime;
        uint128 newBalance = locker.balance + uint128(msg.value);

        if (locker.balance == 0) {
            unlockTime = uint128(block.timestamp + _secondsToLockMoney);
        } else {
            uint128 newUnlockTime = uint128(block.timestamp + _secondsToLockMoney);
            unlockTime = locker.unlockTime > newUnlockTime ? locker.unlockTime : newUnlockTime;
        }

        locker.balance += newBalance;
        locker.unlockTime=unlockTime;

        emit MoneyLocked(msg.sender, newBalance, unlockTime);
    }

    function getUSDPrice(uint256 ethValue) internal view returns (uint256 price) {
        return (ethValue * getLatestETHToUSDPrice()) / 1e18;
    }

    function getLatestETHToUSDPrice() internal view returns (uint256 price) {
        (, int256 rawPrice,,,) = iPriceFeed.latestRoundData();

        if (rawPrice < 0) {
            revert Vault__PriceIsNegative();
        }

        return uint256(rawPrice) * 1e10;
    }
}
