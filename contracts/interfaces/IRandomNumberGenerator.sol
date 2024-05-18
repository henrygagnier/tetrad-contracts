// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRandomNumberGenerator {
    function generate(uint256 _id) external returns (uint256 requestId);
}