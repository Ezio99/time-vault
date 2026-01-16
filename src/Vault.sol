// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";



contract Vault {
    error Vault__PriceIsNegative();
    error Vault__NotEnoughEthSent();

    mapping(address client => uint256 balance) sBalances;
    address private immutable iOwner;
    AggregatorV3Interface private immutable iPriceFeed;

    uint256 private constant MIN_USD_PRICE_TO_STORE = 5;

    constructor(address priceFeedAddress) {
        iOwner = msg.sender;
        iPriceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    function deposit(uint256 _secondsToLockMoney) payable external{
        if(msg.value)
        
    }

    function getUSDPrice(uint256 ethValue) view internal returns(uint256 price){
        return (ethValue * getLatestETHToUSDPrice()) / 1e18;
    }


    function getLatestETHToUSDPrice() view internal returns(uint256 price){
        (,int256 rawPrice,,,) = iPriceFeed.latestRoundData();

        if(rawPrice<0){
            revert Vault__PriceIsNegative();
        }

        return uint256(rawPrice)* 1e10;


    }

    
}