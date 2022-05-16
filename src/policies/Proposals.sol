// SPDX-License-Identifier: AGPL-3.0-only

// The Proposal Policy submits & activates instructions in a INSTR module

pragma solidity ^0.8.10;

import {IKernel, Policy} from "../Kernel.sol";
import '../modules/INSTR.sol';

contract Proposals is Policy {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////


    INSTR private Instructions;
    ROLES private Roles;

    constructor(IKernel kernel_) Policy(kernel_) {}

    function configureReads() external override {
      INSTR = INSTR(getModuleAddress("INSTR")); 
      ROLES = ROLES(getModuleAddress("ROLES"));
    }

    function requestWrites() external returns(bytes5[]) {
      ["INSTR"];
    }


    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Variables                                //
    /////////////////////////////////////////////////////////////////////////////////


    error Proposals_Not_Authorized();
    error Proposals_Already_Endorsed();

    event ProposalSubmitted(uint256 instructionsId);
    event ProposalActivated(uint256 instructionsId);

    struct Proposal {
      bytes32 proposalName;
      address proposer;
    }

    mapping(uint256 => Proposal) public proposalForInstructionsId;
    mapping(address => uint256) public developerEndorsementForProposal;
    mapping(uint256 => uint256) public totalEndorsementsForProposal;


    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Interface                                //
    /////////////////////////////////////////////////////////////////////////////////


    function submitProposal(bytes32 proposalName_, Instruction[] calldata instructions_) external {
      if (ROLES.isRole("Developer", msg.sender) == false) { revert Proposals_Not_Authorized(); }

      uint256 instructionsId = INSTR.store(instructions_);
      proposalForInstructionsId[instructionsId] = Proposal(proposalName_, msg.sender);
    }


    function endorseProposal(instructionsId_) external {
      if (ROLES.isRole("Developer", msg.sender) == false) { revert Proposals_Not_Authorized(); }
      if (developerEndorsementForProposal[msg.sender] == true) { revert Proposals_Already_Endorsed(); }

      developerEndorsementForProposal[msg.sender] = true;
      totalEndorsementsForProposal[instructionsId_] ++;

      if (totalEndorsementsForProposal[instructionsId_] == 3) {
        INSTR.activate(instructionsId);
      }
    }
}