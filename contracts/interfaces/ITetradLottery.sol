// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITetradLottery {
    event LotteryNumberDrawn(
        uint256 indexed lotteryId,
        uint256 finalNumber,
        uint256 countWinningTickets
    );
    event TicketsClaim(
        address indexed claimer,
        uint256 amount,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );
    event TicketsPurchase(
        address indexed buyer,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );

    function buyTickets(uint32[] memory _numbers) external payable;

     function makeLotteryClaimable(uint256 _id, uint256 _result) external;

    function claimTickets(
        uint256 _id,
        uint256[] memory _ticketIds,
        uint32[] memory _brackets
    ) external;

    function drawLottery(uint256 _id) external;
}