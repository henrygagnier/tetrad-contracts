// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./randomNumberGenerator.sol";

contract Lottery is RandomNumberGenerator {
    constructor(uint64 _subscriptionId, address _coordinator)
        RandomNumberGenerator(_subscriptionId, _coordinator)
    {}

    function buyTickets(uint256[5][] memory numbers) external {
        
    }
    function claimTickets(uint256 _id) external {
        
    }
    function drawLottery(uint256 _id) external {
        
    }
}
