// SPDX-License-Identifier: AGPL-3.0-only

// The Voting Policy approves & executes protocol upgrade instructions in the Kernel

pragma solidity ^0.8.10;

import {IKernel, Policy} from "../Kernel.sol";
import {INSTR, ActiveInstructions} from '../modules/INSTR.sol';

contract Voting is Policy {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////


    INSTR private Instructions;

    constructor(IKernel kernel_) Policy(kernel_) {}

    function configureReads() external override {
      INSTR = INSTR(getModuleAddress("INSTR"));
      ROLES = ROLES(getModuleAddress("ROLES")); 
      VOTES = VOTES(getModuleAddress("VOTES"));
    }

    function requestWrites() external returns(bytes5[]) {
      ["INSTR"];
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Variables                                //
    /////////////////////////////////////////////////////////////////////////////////


    error Voting_Not_Authorized();
    error Cannot_Cast_Multiple_Votes();

    event QuorumThresholdSet(uint256 newThreshold);

    uint256 public quoromThreshold = 2000; // 20%
    uint256 proposalExpiry = 604800; // 1 week in seconds 

    mapping(uint256 => uint256) public totalYesVotesForInstructions;
    mapping(uint256 => uint256) public totalNoVotesForInstructions;
    mapping(address => mapping(uint256 => uint256)) public userVotesForInstructions;


    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Interface                                //
    /////////////////////////////////////////////////////////////////////////////////


    function setQuorumThreshold(uint256 newThreshold_) external {
      if (ROLES.isRole("Policy", msg.sender) { revert Voting_Not_Authorized(); }
    
      quoromThreshold = newThreshold_;

      emit QuorumThresholdSet(newThreshold_);
    }

    function vote(bool vote_) external {
      // CAUTION: We must think about how votes are counted/adjusted and whether the outstanding votes can change during the voting period
      // Users adding votes after they cast may affect quorum calculations and potentially brick the governance in a case where a user
      // massively increases the amount of votes such that the quorum can no longer be met after they cast their vote

      uint256 totalVotes = VOTES.totalVotes();
      uint256 userVotes = VOTES.getVotesForUser(msg.sender);
      // not sure if this works to fetch data
      ActiveInstructions active = INSTR.active();
      uint256 instructionsId = active.instructionsId;
      uint256 expiry = active.timestamp + proposalExpiry;

      
      if (instructionsId == 0) { revert Cannot_Cast_Multiple_Votes(); }
      if (userVotesForInstructions[msg.sender][instructionsId] != 0) { revert Cannot_Cast_Multiple_Votes(); }

      if (block.timestamp >= expiry) {
        INSTR.deactivate();
        return;
      }

      userVotesForInstructions[msg.sender][instructionsId] = userVotes;

      if (vote_ == true) {
        totalYesVotesForInstructions[instructionsId] += userVotes;
      } else {
        totalNoVotesForInstructions[instructionsId] += userVotes;
      }

      uint256 totalVotesCasted = totalYesVotesForInstructions[instructionsId] + totalNoVotesForInstructions[instructionsId];
      bool quorumFulfilled = (totalVotesCasted * 10000 / totalVotes) >= quoromThreshold;
      bool isYesMajority = totalYesVotesForInstructions[instructionsId] > totalNoVotesForInstructions[instructionsId];

      if (quorumFulfilled && isYesMajority) {
        INSTR.execute();
        INSTR.deactivate();
      }
    }
}