// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vault {
    error Vault__PriceIsNegative();
    error Vault__NotEnoughEthSent();
    error Vault__TooMuchTimeToLock();
    error Vault__TooLittleTimeToLock();
    error Vault__NotUnlockTime();
    error Vault__NoLocker();
    error Vault__ErrorWhileSendingBalance();
    error Vault__TokenTransferFailed();

    event MoneyLocked(
        address indexed client, address indexed token, address indexed beneficiary, uint256 unlockTime, uint256 balance
    );

    struct Locker {
        uint256 balance;
        uint256 unlockTime;
    }

    //Hash(Token,Depositer,Beneficiary) -> Locker
    mapping(bytes32 => Locker) private sLockers;
    address private immutable I_OWNER;
    AggregatorV3Interface public immutable I_PRICE_FEED;

    uint256 public constant MIN_USD_PRICE_TO_STORE = 5 * 1e18;
    uint256 public constant MIN_TIME_TO_LOCK = 60;
    uint256 public constant MAX_TIME_TO_LOCK = 60 * 60 * 24 * 365 * 10;
    address public constant ETH_ADDRESS = address(0);

    constructor(address priceFeedAddress) {
        I_OWNER = msg.sender;
        I_PRICE_FEED = AggregatorV3Interface(priceFeedAddress);
    }

    function depositEth(uint256 _secondsToLockMoney, address _beneficiary) external payable {
        if (getUsdPrice(msg.value) < MIN_USD_PRICE_TO_STORE) {
            revert Vault__NotEnoughEthSent();
        }

        _deposit(ETH_ADDRESS, _secondsToLockMoney, msg.value, _beneficiary);
    }

    function depositToken(address _token, uint256 _amount, uint256 _secondsToLockMoney, address _beneficiary) external {
        if (_token == ETH_ADDRESS) revert Vault__NotEnoughEthSent();

        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (!success) revert Vault__TokenTransferFailed();

        _deposit(_token, _secondsToLockMoney, _amount, _beneficiary);
    }

    function _deposit(address _token, uint256 _secondsToLock, uint256 _amount, address _beneficiary) internal {
        if (_secondsToLock < MIN_TIME_TO_LOCK) revert Vault__TooLittleTimeToLock();
        if (_secondsToLock > MAX_TIME_TO_LOCK) revert Vault__TooMuchTimeToLock();

        bytes32 lockerId = getLockerId(_token, msg.sender, _beneficiary);

        Locker storage locker = sLockers[lockerId];

        uint256 unlockTime;
        if (locker.balance == 0) {
            unlockTime = (block.timestamp + _secondsToLock);
        } else {
            uint256 newUnlockTime = block.timestamp + _secondsToLock;
            unlockTime = locker.unlockTime > newUnlockTime ? locker.unlockTime : newUnlockTime;
        }

        locker.unlockTime = unlockTime;
        locker.balance += _amount;

        emit MoneyLocked(msg.sender, _token, _beneficiary, unlockTime, _amount);
    }

    function withdraw(address _token, address _depositor) external {
        bytes32 lockerId = getLockerId(_token, _depositor, msg.sender);
        Locker memory mLocker = sLockers[lockerId];

        if (mLocker.balance == 0) {
            revert Vault__NoLocker();
        }

        if (mLocker.unlockTime > block.timestamp) {
            revert Vault__NotUnlockTime();
        }

        delete sLockers[lockerId];

        if (_token == ETH_ADDRESS) {
            (bool callSuccess,) = payable(msg.sender).call{value: mLocker.balance}("");

            if (!callSuccess) {
                revert Vault__ErrorWhileSendingBalance();
            }
        } else {
            bool success = IERC20(_token).transfer(msg.sender, mLocker.balance);
            if (!success) revert Vault__ErrorWhileSendingBalance();
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

    function getLockerId(address _token, address _depositor, address _beneficiary) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_token, _depositor, _beneficiary));
    }

    function getLocker(address _token, address _depositor, address _beneficiary) external view returns (Locker memory) {
        bytes32 lockerId = getLockerId(_token, _depositor, _beneficiary);
        return sLockers[lockerId];
    }

    function getOwner() public view returns (address) {
        return I_OWNER;
    }
}
