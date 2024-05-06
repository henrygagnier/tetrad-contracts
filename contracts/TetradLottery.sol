// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract TetradLottery {
    struct Lottery {
        uint256[6] rewardsPerBracket;
        uint256[6] countWinnersPerBracket;
        uint256 firstTicketId;
        uint256 amountCollected;
        uint256 totalAmountCollected;
        uint256 requestId;
        uint32 finalNumber;
    }

    struct Ticket {
        uint32 number;
        address owner;
    }

    mapping(uint256 => Lottery) lotteries;
    mapping(uint256 => Ticket) tickets;
    mapping(uint256 => uint256) rewardsBreakdown; // 0: 1 matching number // 5: 6 matching numbers

    uint256 public price = 500000000000000;
    uint256 currentTicketId;

    mapping(uint256 => mapping(uint32 => uint256))
        private _numberTicketsPerLotteryId;
    mapping(address => mapping(uint256 => uint256[]))
        private _userTicketIdsPerLotteryId;
    mapping(uint32 => uint32) private bracketCalculator;

    VRFCoordinatorV2Interface internal randomNumberGenerator;

    event LotteryNumberDrawn(
        uint256 indexed lotteryId,
        uint256 finalNumber,
        uint256 countWinningTickets
    );
    event TicketsPurchase(
        address indexed buyer,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );
    event TicketsClaim(
        address indexed claimer,
        uint256 amount,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );

    function buyTickets(uint32[] calldata _numbers) external payable {
        if (_numbers.length == 0) revert();
        if (_numbers.length * price != msg.value) revert();

        uint256 id = block.timestamp / 24 hours;

        for (uint256 i = 0; i < _numbers.length; i++) {
            uint32 thisTicketNumber = _numbers[i];

            if (thisTicketNumber < 1000000 || thisTicketNumber > 1999999)
                revert();

            _numberTicketsPerLotteryId[id][1 + (thisTicketNumber % 10)]++;
            _numberTicketsPerLotteryId[id][11 + (thisTicketNumber % 100)]++;
            _numberTicketsPerLotteryId[id][111 + (thisTicketNumber % 1000)]++;
            _numberTicketsPerLotteryId[id][1111 + (thisTicketNumber % 10000)]++;
            _numberTicketsPerLotteryId[id][
                11111 + (thisTicketNumber % 100000)
            ]++;
            _numberTicketsPerLotteryId[id][
                111111 + (thisTicketNumber % 1000000)
            ]++;

            _userTicketIdsPerLotteryId[msg.sender][id].push(currentTicketId);

            tickets[currentTicketId] = Ticket({
                number: thisTicketNumber,
                owner: msg.sender
            });

            currentTicketId++;
        }

        lotteries[id].amountCollected += (msg.value);
        lotteries[id].totalAmountCollected += (msg.value);
    }

    function claimTickets(
        uint256 _id,
        uint256[] calldata _ticketIds,
        uint32[] calldata _brackets
    ) external {
        if (_ticketIds.length != _brackets.length) revert();
        if (_ticketIds.length == 0) revert();
        if (lotteries[_id].finalNumber == 0) revert();

        uint256 rewardToTransfer;

        for (uint256 i = 0; i < _ticketIds.length; i++) {
            require(_brackets[i] < 6, "Bracket out of range"); // Must be between 0 and 5

            uint256 thisTicketId = _ticketIds[i];

            require(
                lotteries[_id + 1].firstTicketId > thisTicketId,
                "TicketId too high"
            );
            require(
                lotteries[_id].firstTicketId <= thisTicketId,
                "TicketId too low"
            );
            require(msg.sender == tickets[thisTicketId].owner, "Not the owner");

            // Update the lottery ticket owner to 0x address
            tickets[thisTicketId].owner = address(0);

            uint256 rewardForTicketId = calculateRewardsForTicketId(
                _id,
                thisTicketId,
                _brackets[i]
            );

            // Check user is claiming the correct bracket
            require(rewardForTicketId != 0, "No prize for this bracket");

            if (_brackets[i] != 5) {
                require(
                    calculateRewardsForTicketId(
                        _id,
                        thisTicketId,
                        _brackets[i] + 1
                    ) == 0,
                    "Bracket must be higher"
                );
            }

            // Increment the reward to transfer
            rewardToTransfer += rewardForTicketId;
        }

        // Transfer money to msg.sender
        (bool sent, ) = (msg.sender).call{value: rewardToTransfer}("");
        if (!sent) revert();

        emit TicketsClaim(msg.sender, rewardToTransfer, _id, _ticketIds.length);
    }

    function calculateRewardsForTicketId(
        uint256 _id,
        uint256 _ticketId,
        uint32 _bracket
    ) internal view returns (uint256) {
        uint32 winningTicketNumber = lotteries[_id].finalNumber;
        uint32 userNumber = tickets[_ticketId].number;

         uint32 transformedWinningNumber = bracketCalculator[_bracket] +
            (winningTicketNumber % (uint32(10)**(_bracket + 1)));

        uint32 transformedUserNumber = bracketCalculator[_bracket] + (userNumber % (uint32(10)**(_bracket + 1)));

        if (transformedWinningNumber == transformedUserNumber) {
            return lotteries[_id].rewardsPerBracket[_bracket];
        } else {
            return 0;
        }
    }

    function drawLottery(uint256 _id) external {
        if ((block.timestamp / 24 hours) <= _id) revert();
        if (lotteries[_id].finalNumber == 0) revert();
        lotteries[_id + 1].firstTicketId = currentTicketId + 1;
        //lotteries[_id].requestId = generate(_id);
    }

    function makeLotteryClaimable(uint256 _id, uint256 _result) internal {
        uint32 finalNumber = uint32(1000000 + (_result % 1000000));

        uint256 numberAddressesInPreviousBracket;

        for (uint32 i = 0; i < 6; i++) {
            uint32 j = 5 - i;
            uint32 transformedWinningNumber = bracketCalculator[j] +
                (finalNumber % (uint32(10)**(j + 1)));

            lotteries[_id].countWinnersPerBracket[j] =
                _numberTicketsPerLotteryId[_id][transformedWinningNumber] -
                numberAddressesInPreviousBracket;

            // A. If number of users for this _bracket number is superior to 0
            if (
                (_numberTicketsPerLotteryId[_id][transformedWinningNumber] -
                    numberAddressesInPreviousBracket) != 0
            ) {
                // B. If rewards at this bracket are > 0, calculate, else, report the numberAddresses from previous bracket
                if (rewardsBreakdown[j] != 0) {
                    lotteries[_id].rewardsPerBracket[j] +=
                        ((rewardsBreakdown[j] *
                            lotteries[_id].amountCollected) /
                            (_numberTicketsPerLotteryId[_id][
                                transformedWinningNumber
                            ] - numberAddressesInPreviousBracket)) /
                        10000;

                    numberAddressesInPreviousBracket = _numberTicketsPerLotteryId[
                        _id
                    ][transformedWinningNumber];
                }
                // A. No CAKE to distribute, they are added to the next round
            } else {
                lotteries[_id + 1].totalAmountCollected +=
                    (rewardsBreakdown[j] * lotteries[_id].amountCollected) /
                    10000;
                lotteries[_id + 1].rewardsPerBracket[j] +=
                    (rewardsBreakdown[j] * lotteries[_id].amountCollected) /
                    10000 +
                    lotteries[_id].rewardsPerBracket[j];
            }
        }

        lotteries[_id].finalNumber = finalNumber;
    }
}
