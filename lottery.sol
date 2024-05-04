// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts@1.1.0/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts@1.1.0/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "./randomNumberGenerator.sol";

contract TetradLottery is VRFConsumerBaseV2 {
    struct Lottery {
        uint256[5] rewardsBreakdown; // 0: 1 matching number // 4: 5 matching numbers
        uint256[5] cakePerBracket;
        uint256[5] countWinnersPerBracket;
        uint256 firstTicketId;
        uint256 amountCollected;
        uint256 requestId;
        uint32 finalNumber;
    }
    
    struct Ticket {
        uint32 number;
        address owner;
    }

    mapping(uint256 => Lottery) lotteries;
    mapping(uint256 => Ticket) tickets;

    uint256 public treasuryFees = 100;

    uint256 public price = 500000000000000;
    uint256 currentTicketId;

    mapping(uint256 => mapping(uint32 => uint256)) private _numberTicketsPerLotteryId;
    mapping(address => mapping(uint256 => uint256[])) private _userTicketIdsPerLotteryId;

    error InvalidTickets();

    function buyTickets(uint32[] calldata _numbers) external payable {
        if (_numbers.length == 0) revert();
        if (_numbers.length * price != msg.value) revert InvalidTickets();

        uint256 id = block.timestamp / 24 hours;
        if (lotteries[id].amountCollected == 0) {
            lotteries[id].firstTicketId = currentTicketId + 1;
        }

        for (uint256 i = 0; i < _numbers.length; i++) {
            uint32 thisTicketNumber = _numbers[i];

            if(thisTicketNumber < 1000000 || thisTicketNumber > 1999999) revert InvalidTickets();

            _numberTicketsPerLotteryId[id][1 + (thisTicketNumber % 10)]++;
            _numberTicketsPerLotteryId[id][11 + (thisTicketNumber % 100)]++;
            _numberTicketsPerLotteryId[id][111 + (thisTicketNumber % 1000)]++;
            _numberTicketsPerLotteryId[id][1111 + (thisTicketNumber % 10000)]++;
            _numberTicketsPerLotteryId[id][11111 + (thisTicketNumber % 100000)]++;
            _numberTicketsPerLotteryId[id][111111 + (thisTicketNumber % 1000000)]++;

            _userTicketIdsPerLotteryId[msg.sender][id].push(currentTicketId);

            tickets[currentTicketId] = Ticket({number: thisTicketNumber, owner: msg.sender});

            currentTicketId++;
        }

        lotteries[id].amountCollected += (msg.value);
    }

    function claimTickets(uint256 _id) external {
        
    }

    function drawLottery(uint256 _id) external {
        if ((block.timestamp / 24 hours) >= _id) revert();
        if (lotteries[_id].finalNumber == 0) revert();
        lotteries[_id].requestId = generate(_id);
    }

    function makeLotteryClaimable(uint256 _id, uint256 _result) internal {
        
    }

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
        uint256 lotteryId;
    }
    mapping(uint256 => RequestStatus)
        public requests;
    VRFCoordinatorV2Interface COORDINATOR;

    uint64 subscriptionId;

    // https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash = 0x027f94ff1465b3525f9fc03e9ff7d6d2c0953482246dd6ae07570c45d6631414;
    uint32 callbackGasLimit = 500000;
    uint16 requestConfirmations = 3;

    constructor(
        uint64 _subscriptionId, address _coordinator
    )
        VRFConsumerBaseV2(_coordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            _coordinator
        );
        subscriptionId = _subscriptionId;
    }

    function generate(uint256 _id)
        internal
        returns (uint256 requestId)
    {
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );
        requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false,
            lotteryId: _id
        });
        emit RequestSent(requestId, 1);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(requests[_requestId].exists, "request not found");
        requests[_requestId].fulfilled = true;
        requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(requests[_requestId].exists, "request not found");
        RequestStatus memory request = requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}
