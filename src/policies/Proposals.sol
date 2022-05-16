// SPDX-License-Identifier: AGPL-3.0-only

// The Proposal Policy submits & activates instructions in a INSTR module

pragma solidity ^0.8.10;

import {IKernel, Policy} from "../Kernel.sol";
import '../modules/INSTR.sol';

contract Proposals is Policy {

    /////////////////////////////////////////////////////////////////////////////////
    //                      DefaultOS Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    INSTR private Instructions;

    constructor(IKernel kernel_) Policy(kernel_) {}

    function configureReads() external override {
      INSTR = INSTR(getModuleAddress("INSTR")); 
    }

    function requestWrites() external returns(bytes5[]) {
      ["INSTR"];
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Interface                                //
    /////////////////////////////////////////////////////////////////////////////////

    struct Proposal {
      bytes32 proposalName;
      address proposer;
    }

    mapping(uint256 => Proposal) proposalForInstructionsId;


    event ProposalSubmitted(uint256 instructionsId);
    event ProposalActivated(uint256 instructionsId);

    function submitProposal(bytes32 proposalName_, Instruction[] calldata instructions_) {
      uint256 instructionsId = INSTR.storeInstructions(instructions_);
      proposalForInstructionsId[instructionsId] = Proposal(proposalName_, msg.sender);
    }

    function activateProposal(uint256 instructionsId) {
      INSTR.activate(instructionsId);
    }
}