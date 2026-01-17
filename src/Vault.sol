// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract Vault {
    using SafeCast for uint256;

    error Vault__PriceIsNegative();
    error Vault__NotEnoughEthSent();
    error Vault__TooMuchTimeToLock();
    error Vault__TooLittleTimeToLock();
    error Vault__NotUnlockTime();
    error Vault__NoLocker();
    error Vault__ErrorWhileSendingBalance();

    event MoneyLocked(address indexed client, uint128 indexed balance, uint128 indexed unlockTime);

    struct Locker {
        uint128 balance;
        uint128 unlockTime;
    }

    mapping(address => Locker) private sBalances;
    address private immutable I_OWNER;
    AggregatorV3Interface public immutable I_PRICE_FEED;

    uint256 public constant MIN_USD_PRICE_TO_STORE = 5 * 1e18;
    uint256 public constant MIN_TIME_TO_LOCK = 60;
    uint256 public constant MAX_TIME_TO_LOCK = 60 * 60 * 24 * 365 * 10;

    constructor(address priceFeedAddress) {
        I_OWNER = msg.sender;
        I_PRICE_FEED = AggregatorV3Interface(priceFeedAddress);
    }

    function deposit(uint256 _secondsToLockMoney) external payable {
        if (_secondsToLockMoney < MIN_TIME_TO_LOCK) {
            revert Vault__TooLittleTimeToLock();
        }

        if (_secondsToLockMoney > MAX_TIME_TO_LOCK) {
            revert Vault__TooMuchTimeToLock();
        }

        if (getUsdPrice(msg.value) < MIN_USD_PRICE_TO_STORE) {
            revert Vault__NotEnoughEthSent();
        }

        Locker storage locker = sBalances[msg.sender];

        uint128 unlockTime;
        uint128 newBalance = msg.value.toUint128();

        if (locker.balance == 0) {
            unlockTime = (block.timestamp + _secondsToLockMoney).toUint128();
        } else {
            uint128 newUnlockTime = (block.timestamp + _secondsToLockMoney).toUint128();
            unlockTime = locker.unlockTime > newUnlockTime ? locker.unlockTime : newUnlockTime;
        }

        locker.balance += newBalance;
        locker.unlockTime = unlockTime;

        emit MoneyLocked(msg.sender, newBalance, unlockTime);
    }

    function withdraw() external {
        Locker memory mLocker = sBalances[msg.sender];

        if (mLocker.balance == 0) {
            revert Vault__NoLocker();
        }

        if (mLocker.unlockTime > block.timestamp) {
            revert Vault__NotUnlockTime();
        }

        delete sBalances[msg.sender];

        (bool callSuccess,) = payable(msg.sender).call{value: mLocker.balance}("");

        if (!callSuccess) {
            revert Vault__ErrorWhileSendingBalance();
        }
    }

    function getUsdPrice(uint256 ethValue) public view returns (uint256 price) {
        return (ethValue * getLatestEthToUsdPrice()) / 1e18;
    }

    function getLatestEthToUsdPrice() public view returns (uint256 price) {
        (, int256 rawPrice,,,) = I_PRICE_FEED.latestRoundData();

        if (rawPrice < 0) {
            revert Vault__PriceIsNegative();
        }

        return uint256(rawPrice) * 1e10;
    }

    function getLocker(address _address) public view returns (Locker memory) {
        return sBalances[_address];
    }
}
