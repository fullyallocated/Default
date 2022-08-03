// SPDX-License-Identifier: AGPL-3.0-only

// The Governance Policy submits & activates instructions in a INSTR module

pragma solidity ^0.8.15;

import "../Kernel.sol";
import { DefaultInstructions, Actions, Instruction } from "../modules/INSTR.sol";
import { DefaultVotes } from "../modules/VOTES.sol";


interface IGovernance {

    struct ProposalMetadata {
        bytes32 proposalName;
        address proposer;
        uint256 submissionTimestamp;
    }

    struct ActivatedProposal {
        uint256 instructionsId;
        uint256 activationTimestamp;
    }
    
    event ProposalSubmitted(uint256 instructionsId);
    event ProposalEndorsed(uint256 instructionsId, address voter, uint256 amount);
    event ProposalActivated(uint256 instructionsId, uint256 timestamp);
    event WalletVoted(uint256 instructionsId, address voter, bool for_, uint256 userVotes);
    event ProposalExecuted(uint256 instructionsId);
    
    // proposing
    error NotEnoughVotesToPropose();

    // endorsing
    error CannotEndorseNullProposal();
    error CannotEndorseInvalidProposal();

    // activating
    error NotAuthorizedToActivateProposal();
    error NotEnoughEndorsementsToActivateProposal();
    error ProposalAlreadyActivated();
    error ActiveProposalNotExpired();
    error SubmittedProposalHasExpired();

    // voting
    error NoActiveProposalDetected();
    error UserAlreadyVoted();

    // executing
    error NotEnoughVotesToExecute();
    error ExecutionTimelockStillActive();

    // claiming
    error VotingTokensAlreadyReclaimed();
    error CannotReclaimTokensForActiveVote();
    error CannotReclaimZeroVotes();
}


contract Governance is Policy, IGovernance {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////


    DefaultInstructions public INSTR;
    DefaultVotes public VOTES;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies() external override onlyKernel returns (Keycode[] memory dependencies) {
        dependencies = new Keycode[](2);
        
        dependencies[0] = toKeycode("INSTR");
        INSTR = DefaultInstructions(getModuleAddress(toKeycode("INSTR")));
        
        dependencies[1] = toKeycode("VOTES");
        VOTES = DefaultVotes(getModuleAddress(toKeycode("VOTES")));
    }

    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](4);
        requests[0] = Permissions(toKeycode("INSTR"), INSTR.store.selector);
        requests[1] = Permissions(toKeycode("VOTES"), VOTES.mintTo.selector);
        requests[2] = Permissions(toKeycode("VOTES"), VOTES.burnFrom.selector);
        requests[3] = Permissions(toKeycode("VOTES"), VOTES.transferFrom.selector);
    }


    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Variables                                //
    /////////////////////////////////////////////////////////////////////////////////


    // currently active proposal
    ActivatedProposal public activeProposal;

    mapping(uint256 => ProposalMetadata) public getProposalMetadata;
    mapping(uint256 => uint256) public totalEndorsementsForProposal;
    mapping(uint256 => mapping(address => uint256)) public userEndorsementsForProposal;
    mapping(uint256 => bool) public proposalHasBeenActivated;
    mapping(uint256 => uint256) public yesVotesForProposal;
    mapping(uint256 => uint256) public noVotesForProposal;
    mapping(uint256 => mapping(address => uint256)) public userVotesForProposal;
    mapping(uint256 => mapping(address => bool)) public tokenClaimsForProposal;

    uint256 public constant ACTIVATION_DEADLINE = 2 weeks; // amount of time a submitted proposal has to activate before it expires
    uint256 public constant GRACE_PERIOD = 1 weeks; // amount of time an activated proposal can stay up before it can be replaced
    uint256 public constant ENDORSEMENT_THRESHOLD = 20; // required percentage of total supply to activate a proposal (in percentage)
    uint256 public constant EXECUTION_THRESHOLD = 33; // required net votes to execute a proposal (in percentage)
    uint256 public constant VOTER_REWARD_RATE = 40;  // voter reward rate (in basis points)


    /////////////////////////////////////////////////////////////////////////////////
    //                              View Functions                                 //
    /////////////////////////////////////////////////////////////////////////////////


    function getMetadata(uint256 instructionsId_) public view returns (ProposalMetadata memory) {
        return getProposalMetadata[instructionsId_];
    }


    function getActiveProposal() public view returns (ActivatedProposal memory) {
        return activeProposal;
    }


    /////////////////////////////////////////////////////////////////////////////////
    //                               User Actions                                  //
    /////////////////////////////////////////////////////////////////////////////////


    function submitProposal(Instruction[] calldata instructions_, bytes32 proposalName_) external {
        // require the proposing wallet to own at least 1% of the outstanding governance power
        if (VOTES.balanceOf(msg.sender) * 100 < VOTES.totalSupply()) {
            revert NotEnoughVotesToPropose();
        }

        // store the proposed instructions in the INSTR module and save the proposal metadata to the proposal mapping
        uint256 instructionsId = INSTR.store(instructions_);
        getProposalMetadata[instructionsId] = ProposalMetadata(
            proposalName_,
            msg.sender,
            block.timestamp
        );

        // emit the corresponding event
        emit ProposalSubmitted(instructionsId);
    }

    function endorseProposal(uint256 instructionsId_) external {
        // get the current votes of the user
        uint256 userVotes = VOTES.balanceOf(msg.sender);

        // revert if endorsing null instructionsId
        if (instructionsId_ == 0) {
            revert CannotEndorseNullProposal();
        }

        // revert if endorsed instructions are empty
        Instruction[] memory instructions = INSTR.getInstructions(instructionsId_);
        if (instructions.length == 0) {
            revert CannotEndorseInvalidProposal();
        }

        // undo any previous endorsement the user made on these instructions
        uint256 previousEndorsement = userEndorsementsForProposal[instructionsId_][msg.sender];
        totalEndorsementsForProposal[instructionsId_] -= previousEndorsement;

        // reapply user endorsements with most up-to-date votes
        userEndorsementsForProposal[instructionsId_][msg.sender] = userVotes;
        totalEndorsementsForProposal[instructionsId_] += userVotes;

        // emit the corresponding event
        emit ProposalEndorsed(instructionsId_, msg.sender, userVotes);
    }

    function activateProposal(uint256 instructionsId_) external {
        // get the proposal to be activated
        ProposalMetadata memory proposal = getProposalMetadata[instructionsId_];

        // only allow the proposer to activate their proposal
        if (msg.sender != proposal.proposer) {
            revert NotAuthorizedToActivateProposal();
        }

        // proposals must be activated within 2 weeks of submission or they expire
        if (block.timestamp > proposal.submissionTimestamp + ACTIVATION_DEADLINE) {
            revert SubmittedProposalHasExpired();
        }

        // require endorsements from at least 20% of the total outstanding governance power
        if ((totalEndorsementsForProposal[instructionsId_] * 100) < VOTES.totalSupply() * ENDORSEMENT_THRESHOLD) {
            revert NotEnoughEndorsementsToActivateProposal();
        }

        // ensure the proposal is being activated for the first time
        if (proposalHasBeenActivated[instructionsId_] == true) {
            revert ProposalAlreadyActivated();
        }

        // ensure the currently active proposal has had at least a week of voting for execution
        if (block.timestamp < activeProposal.activationTimestamp + 1 weeks) {
            revert ActiveProposalNotExpired();
        }

        // activate the proposal
        activeProposal = ActivatedProposal(instructionsId_, block.timestamp);

        // record that the proposal has been activated
        proposalHasBeenActivated[instructionsId_] = true;

        // emit the corresponding event
        emit ProposalActivated(instructionsId_, block.timestamp);
    }

    function vote(bool for_) external {
        // get the amount of user votes
        uint256 userVotes = VOTES.balanceOf(msg.sender);

        // ensure an active proposal exists
        if (activeProposal.instructionsId == 0) {
            revert NoActiveProposalDetected();
        }

        // ensure the user has no pre-existing votes on the proposal
        if (userVotesForProposal[activeProposal.instructionsId][msg.sender] > 0) {
            revert UserAlreadyVoted();
        }

        // record the votes
        if (for_) {
            yesVotesForProposal[activeProposal.instructionsId] += userVotes;
        } else {
            noVotesForProposal[activeProposal.instructionsId] += userVotes;
        }

        // record that the user has casted votes
        userVotesForProposal[activeProposal.instructionsId][msg.sender] = userVotes;

        // transfer voting tokens to contract
        VOTES.transferFrom(msg.sender, address(this), userVotes);

        // emit the corresponding event
        emit WalletVoted(activeProposal.instructionsId, msg.sender, for_, userVotes);
    }

    function executeProposal() external {
        // require the net votes (yes - no) to be greater than 33% of the total voting supply

        uint256 netVotes = yesVotesForProposal[activeProposal.instructionsId] - noVotesForProposal[activeProposal.instructionsId];
        if (netVotes * 100 < VOTES.totalSupply() * EXECUTION_THRESHOLD) {
            revert NotEnoughVotesToExecute();
        }

        // ensure three days have passed before the proposal can be executed
        if (block.timestamp < activeProposal.activationTimestamp + 3 days) {
            revert ExecutionTimelockStillActive();
        }

        // execute the active proposal
        Instruction[] memory instructions = INSTR.getInstructions(activeProposal.instructionsId);

        for (uint256 step; step < instructions.length; ) {
            kernel.executeAction(instructions[step].action, instructions[step].target);
            unchecked { ++step; }
        }

        // reward the proposer with 2% of the token supply
        address proposer = getProposalMetadata[activeProposal.instructionsId].proposer;
        VOTES.mintTo(proposer, VOTES.totalSupply() * 2 / 100);

        // emit the corresponding event
        emit ProposalExecuted(activeProposal.instructionsId);

        // deactivate the active proposal
        activeProposal = ActivatedProposal(0, 0);
    }

    function reclaimVotes(uint256 instructionsId_) external {
        // get the amount of tokens the user voted with
        uint256 userVotes = userVotesForProposal[instructionsId_][msg.sender];

        // ensure the user is not claiming empty votes
        if (userVotes == 0) {
            revert CannotReclaimZeroVotes();
        }

        // ensure the user is not claiming for the active propsal
        if (instructionsId_ == activeProposal.instructionsId) {
            revert CannotReclaimTokensForActiveVote();
        }

        // ensure the user has not already claimed before for this proposal
        if (tokenClaimsForProposal[instructionsId_][msg.sender] == true) {
            revert VotingTokensAlreadyReclaimed();
        }

        // record the voting tokens being claimed from the contract
        tokenClaimsForProposal[instructionsId_][msg.sender] = true;

        // return the tokens back to the user
        VOTES.transferFrom(address(this), msg.sender, userVotes);

        // mint a bonus reward (+.4%) to the user for participation
        VOTES.mintTo(msg.sender, userVotes * VOTER_REWARD_RATE / 10000);
    }
}
