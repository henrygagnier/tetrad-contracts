// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract ProgrammableTokenTransfers is OwnerIsCreator {
    using SafeERC20 for IERC20;

    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error DestinationChainNotAllowed(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        CCIPData data, // The text being sent.
        address token, // The token address that was transferred.
        uint256 tokenAmount, // The token amount that was transferred.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );

    struct CCIPData {
        uint256 call;
        uint32[] tickets;
        uint256[] ticketIds;
        uint256 id;
        uint32[] brackets;
    }

    IRouterClient public router;

    uint64 public mainContractChain = 3478487238524512106;
    address public mainContractAddress =
        0xD182a4F172dFCee838adC4a4c6cB7A98a2988597;

    constructor(address _router) {
        router = IRouterClient(_router);
    }

    function buyTickets(uint32[] calldata _tickets)
        external
        payable
        returns (bytes32 messageId)
    {
        CCIPData memory data = CCIPData(
            0,
            _tickets,
            new uint256[](0),
            0,
            new uint32[](0)
        );

console.log("1");

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            mainContractAddress,
            data,
            address(0),
            msg.value
        );

        uint256 fees = router.getFee(mainContractChain, evm2AnyMessage);

        console.log("2");

        if (fees >= msg.value) revert NotEnoughBalance(msg.value, fees);

        evm2AnyMessage = _buildCCIPMessage(
            mainContractAddress,
            data,
            address(0),
            msg.value - fees
        );
        console.log("3");

        messageId = router.ccipSend{value: fees}(
            mainContractChain,
            evm2AnyMessage
        );

        console.log("4");

        emit MessageSent(
            messageId,
            mainContractChain,
            mainContractAddress,
            data,
            address(0),
            msg.value,
            address(0),
            fees
        );

        return messageId;
    }

    function _buildCCIPMessage(
        address _receiver,
        CCIPData memory _data,
        address _token,
        uint256 _amount
    ) private pure returns (Client.EVM2AnyMessage memory evm2AnyMessage) {
        bytes memory data = abi.encode(_receiver, _data);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });

        evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: data, // Set the encoded payload data
            tokenAmounts: tokenAmounts, // Initialize the array with one element
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            feeToken: address(0)
        });

        return evm2AnyMessage;
    }
}
