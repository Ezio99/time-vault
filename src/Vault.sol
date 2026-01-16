// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;


contract Vault {

    mapping(address client => uint256 balance) sBalances;
    address private immutable iOwner;

    constructor() {
        iOwner = msg.sender;
    }

    function deposit(uint256 _secondsToLockMoney) payable external{
        require()
    }
}