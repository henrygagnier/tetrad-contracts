// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "./interfaces/ITetradLottery.sol";

contract RandomNumberGenerator is VRFConsumerBaseV2 {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
        uint256 lotteryId;
    }

    mapping(uint256 => RequestStatus) public requests;
    VRFCoordinatorV2Interface coordinator;
    ITetradLottery lottery;

    uint64 subscriptionId;

    // https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x027f94ff1465b3525f9fc03e9ff7d6d2c0953482246dd6ae07570c45d6631414;
    uint32 callbackGasLimit = 500000;
    uint16 requestConfirmations = 3;

    modifier onlyLottery() {
        if (msg.sender != address(lottery)) revert();
        _;
    }

    constructor(uint64 _subscriptionId, address _coordinator, address _lottery)
        VRFConsumerBaseV2(_coordinator)
    {
        coordinator = VRFCoordinatorV2Interface(_coordinator);
        lottery = ITetradLottery(_lottery);
        subscriptionId = _subscriptionId;
    }

    function generate(uint256 _id) external onlyLottery() returns (uint256 requestId) {
        requestId = coordinator.requestRandomWords(
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
        uint256 lotteryId = requests[_requestId].lotteryId;
        lottery.makeLotteryClaimable(lotteryId, _randomWords[0]);
        emit RequestFulfilled(_requestId, _randomWords);
    }
}