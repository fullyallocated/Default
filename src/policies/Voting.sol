// SPDX-License-Identifier: AGPL-3.0-only

// The Voting Policy approves & executes protocol upgrade instructions in the Kernel

pragma solidity ^0.8.10;

import {IKernel, Policy} from "../Kernel.sol";
import '../modules/INSTR.sol';

contract Voting is Policy {

    /////////////////////////////////////////////////////////////////////////////////
    //                      DefaultOS Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    INSTR private Instructions;

    constructor(IKernel kernel_) Policy(kernel_) {}

    function configureReads() external override {
      INSTR = INSTR(getModuleAddress("INSTR")); 
      VOTES = VOTES(getModuleAddress("VOTES"));
    }

    function requestWrites() external returns(bytes5[]) {
      ["INSTR"];
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Interface                                //
    /////////////////////////////////////////////////////////////////////////////////

    mapping(uint256 => uint256) getTotalYesVotesForInstructions;
    mapping(uint256 => uint256) getTotalnoVotesForInstructions;

    mapping(address => mapping(uint256 => uint256)) getUserVotesForinstructions;


    function vote(bool vote_) {
      uint256 activeInstruction = INSTR.getActiveInstructions();
      msg.sender
    }

    function activateProposal(uint256 instructionsId) {
      INSTR.activate(instructionsId);
    }
}