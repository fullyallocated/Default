// SPDX-License-Identifier: AGPL-3.0-only

// The Proposal Policy submits & activates instructions in a INSTR module

pragma solidity ^0.8.10;

import {IKernel, Policy} from "../Kernel.sol";
import '../modules/INSTR.sol';

contract Governance is Policy {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////


    INSTR private Instructions;
    ROLES private Roles;


    constructor(IKernel kernel_) Policy(kernel_) {}


    function configureReads() external override {
      INSTR = INSTR(getModuleAddress("INSTR"));
      VOTES = VOTES(getModuleAddress("VOTES")); 
    }


    function requestWrites() external returns(bytes5[]) {
      [ "INSTR" ];
    }


    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Variables                                //
    /////////////////////////////////////////////////////////////////////////////////


    event ProposalSubmitted(uint256 instructionsId);
    event ProposalEndorsed(uint256 instructionsId, address voter, uint256 amount);
    event ProposalActivated(uint256 instructionsId, uint timestamp);


    error Not_Enough_Votes_To_Propose();
    error Not_Authorized_To_Activate_Proposal();
    error Not_Enough_Endorsements_To_Activate_Proposal();
    error Active_Proposal_Not_Expired();
    error Proposal_Previously_Activated();
    error Not_Enough_Votes_To_Propose();
    error Voting_Tokens_Already_Claimed();
    error Cannot_Claim_Active_Voting_Tokens();


    struct Proposal {
      bytes32 proposalName;
      address proposer;
    }


    struct ActivatedProposal {
      uint256 instructionsId;
      uint256 timestamp;
    }


    ActivatedProposal public activeProposal;
    mapping(uint256 => Proposal) public getProposal;
    mapping(uint256 => uint256) public totalEndorsementsForProposal;
    mapping(uint256 => mapping(address => uint256)) public userEndorsementsForProposal;
    mapping(uint256 => bool) public getActivatedProposals;


    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Interface                                //
    /////////////////////////////////////////////////////////////////////////////////


    function submitProposal(bytes32 proposalName_, Instruction[] calldata instructions_) external {

      // require the proposing wallet to own at least 1% of the outstanding governance power
      if ((VOTES.balanceOf(msg.sender) * 100 / VOTES.totalSupply()) < 1) { revert Not_Enough_Votes_To_Propose(); }

      // store the proposed instructions in the INSTR module and save the proposal metadata to the proposal mapping
      uint256 instructionsId = INSTR.store(instructions_);
      getProposal[instructionsId] = Proposal(proposalName_, msg.sender);

      // emit the corresponding event
      emit ProposalSubmitted(instructionsId_);

    }


    function endorseProposal(instructionsId_) external {

      // get the current votes of the user
      uint256 userVotes = VOTES.balanceOf(msg.sender);

      // undo any previous endorsement the user made on these instructions
      uint256 previousEndorsement = userEndorsementsForProposal[instructionsId_][msg.sender];
      totalEndorsementsForProposal[instructionsId_] -= previousEndorsement;      

      // reapply user endorsements with most up-to-date votes
      userEndorsementsForProposal[instructionsId_][msg.sender] = userVotes;
      totalEndorsementsForProposal[instructionsId_] += userVotes;

      // emit the corresponding event
      emit ProposalEndorsed(instructionsId_, msg.sender, userVotes);

    }


    function activateProposal(instructionsId_) external {
      
      // get the proposal to be activated
      Proposal memory proposal = getProposal[instructionsId_];

      // only allow the proposer to be active their proposal
      if (msg.sender != proposal.proposer) { revert Not_Authorized_To_Activate_Proposal(); }

      // require endorsements from at least 20% of the total outstanding governance power
      if (totalEndorsementsForProposal[instructionsId_] * 100 / VOTES.totalSupply() < 20) { revert Not_Enough_Endorsements_To_Activate_Proposal();}

      // ensure the proposal is being activated for the first time
      if (getActivatedProposals[instructionsId_] == true) { revert Proposal_Previously_Activated(); }

      // ensure the current active proposal has had at least two weeks of voting
      if (block.timestamp < activeProposal.timestamp + 1209600) { revert Active_Proposal_Not_Expired(); }

      // activate the proposal
      activeProposal = ActivatedProposal(instructionsId_, VOTES.totalSupply(), block.timestamp);

      // record that the proposal has been activated
      getActivatedProposals[instructionsId_] = true;

      // emit the corresponding event
      emit ProposalActivated(instructionsId_, block.timestamp);

    }


    function vote(bool for_) external {
      
      // get the amount of user votes
      uint256 userVotes = VOTES.balanceOf(msg.sender)

      // ensure the user has no pre-existing votes on the proposal
      if (userVotesForProposal[activeProposal.instructionsId][msg.sender] > 0) { revert User_Already_Voted(); }

      // record the votes
      if (for_) { yesVotesForProposal[activeProposal.instructionsId] += userVotes; }
      else if (!for_) { noVotesForProposal[activeProposal.instructionsId] += userVotes; }

      // transfer voting tokens to contract
      VOTES.transferFrom(msg.sender, address(this), userVotes);
      
      // emit the corresponding event
      emit UserVoted(activeProposal.instructionsId, msg.sender, userVotes);

    }


    function executeProposal() external {

      // calculate net vote (33% threshold): ensure total yes > (total no + (totalSupply() / 3))
      uint256 minimumYesThreshold = noVotesForProposal[activeProposal.instructionsId] + (VOTES.totalSupply() / 3);
      if (yesVotesForProposal[activeProposal.instructionsId] < minimumYesThreshold) { revert Not_Enough_Votes_To_Execute(); }

      // ensure a week has passed before the proposal can be executed
      if (block.timestamp < activeProposal.timestamp + 604800) { revert Active_Proposal_Not_Matured(); }

      // execute the active proposal
      INSTR.execute(activeProposal.instructionsId);

      // deactivate the active proposal
      activeProposal = ActivatedProposal(0, 0, 0);

      // emit the corresponding event
      emit ProposalExecuted(activeProposal.instructionsId);

    }


    function claimVoteTokens(uint256 instructionsId_) external {

      // get the amount of tokens the user voted with
      uint256 userVotes = userVotesForProposal[instructionsId_][msg.sender];

      // ensure the user is not claiming for the active propsal
      if (instructionsId_ == activeProposal.instructionsId) { revert Cannot_Claim_Active_Voting_Tokens(); }

      // ensure the user has not already claimed before for this proposal
      if (tokenClaimsForProposal[instructionsId_][msg.sender] == true) { revert Voting_Tokens_Already_Claimed(); }

      // record the voting tokens being claimed from the contract
      uint256 tokenClaimsForProposal[instructionsId_][msg.sender] = true;

      // return the tokens back to the user
      VOTES.transfer(msg.sender, userVotes);

    }
}