// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./randomNumberGenerator.sol";

contract TetradLottery is RandomNumberGenerator {
    struct Lottery {
        uint256[5] rewardsBreakdown; // 0: 1 matching number // 4: 5 matching numbers
        uint256[5] cakePerBracket;
        uint256[5] countWinnersPerBracket;
        uint256 firstTicketId;
        uint256 amountCollected;
        uint32 finalNumber;
    }
    
    struct Ticket {
        uint32 number;
        address owner;
    }

    mapping(uint256 => Lottery) lotteries;
    mapping(uint256 => Ticket) tickets;

    mapping(address => uint256) retailerFees;
    uint256 treasuryFees;

    uint256 public price = 500000000000000;
    uint256 currentTicketId;

    constructor(uint64 _subscriptionId, address _coordinator)
        RandomNumberGenerator(_subscriptionId, _coordinator)
    {}

    function buyTickets(uint32[] calldata _numbers, address _retailer) external payable {
        if (_numbers.length == 0) revert();
        if (_numbers.length * price != msg.value) revert();

        uint256 id = block.timestamp / 24 hours;
        if (lotteries[id].amountCollected == 0) {
            lotteries[id].firstTicketId = currentTicketId + 1;
        }

        uint256 treasuryFee = (msg.value * 10) / 1000;
        uint256 retailerFee = (msg.value * 10) / 1000;
        treasuryFees += treasuryFee;
        retailerFees[_retailer] += retailerFee;
        lotteries[id].amountCollected += (msg.value - (treasuryFee + retailerFee));
    }

    function claimTickets(uint256 _id) external {
        
    }
    function drawLottery(uint256 _id) external {
        
    }
}
