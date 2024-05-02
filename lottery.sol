// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./randomNumberGenerator.sol";

contract TetradLottery is RandomNumberGenerator {
    struct Lottery {
        uint256[6] rewardsBreakdown; // 0: 1 matching number // 5: 6 matching numbers
        uint256 treasuryFee; // 500: 5% // 200: 2% // 50: 0.5
        uint256[6] cakePerBracket;
        uint256[6] countWinnersPerBracket;
        uint256 firstTicketId;
        uint256 firstTicketIdNextLottery;
        uint256 amountCollected;
        uint32 finalNumber;
    }

    mapping(uint256 => Lottery) lotteries;
    uint256 public price = 500000000000000;

    constructor(uint64 _subscriptionId, address _coordinator)
        RandomNumberGenerator(_subscriptionId, _coordinator)
    {}

    struct Ticket {
        uint32 number;
        address owner;
    }

    function buyTickets(uint32[] calldata _numbers) external payable {
        if (_numbers.length == 0) revert();
        if (_numbers.length * price != msg.value) revert();

        uint256 id = block.timestamp / 24 hours;
    }

    function claimTickets(uint256 _id) external {
        
    }
    function drawLottery(uint256 _id) external {
        
    }
}
