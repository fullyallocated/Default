// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {Kernel, Instruction, Actions} from "src/Kernel.sol";

import {Instructions} from "src/modules/INSTR.sol";
import {Token} from "src/modules/TOKEN.sol";
import {Authorization} from "src/modules/AUTHR.sol";
import {Treasury} from "src/modules/TRSRY.sol";

import {Governance} from "src/policies/Governance.sol";
import {Faucet} from "src/policies/Faucet.sol";

contract SeedData is Script {

    function run() external {
        vm.startBroadcast();

        // deploy kernel
        Kernel kernel = new Kernel();
        console2.log("Kernel deployed at:", address(kernel));

        // deploy modules
        Instructions instr = new Instructions(kernel);
        Token token = new Token(kernel);
        Treasury treasury = new Treasury(kernel);
        Authorization auth = new Authorization(kernel);
        Faucet faucet = new Faucet(kernel);


        // deploy policies
        Governance gov = new Governance(kernel);

        // install modules
        kernel.executeAction(Actions.InstallModule, address(instr));
        kernel.executeAction(Actions.InstallModule, address(token));
        kernel.executeAction(Actions.InstallModule, address(treasury));
        kernel.executeAction(Actions.InstallModule, address(auth));

        // approve policies
        kernel.executeAction(Actions.ApprovePolicy, address(gov));
        kernel.executeAction(Actions.ApprovePolicy, address(faucet));

        // transfer executive powers to governance
        kernel.executeAction(Actions.ChangeExecutor, address(gov));

        // SEED DATA IS HERE

        // create new token module
        Token tokenProposal = new Token(kernel);
        Token tokenProposal1 = new Token(kernel);

        // create proposal 1
        Instruction[] memory instructions = new Instruction[](1);
        instructions[0] = Instruction(Actions.InstallModule, address(tokenProposal));
        bytes32 proposalName = "Test Proposal";
        uint256 proposalId = gov.submitProposal(instructions, proposalName);

        // create proposal 2
        Instruction[] memory instructions1 = new Instruction[](1);
        instructions1[0] = Instruction(Actions.InstallModule, address(tokenProposal1));
        bytes32 proposalName1 = "Malicious Proposal :)";
        uint256 proposal1Id = gov.submitProposal(instructions1, proposalName1);

        // mint account 1 tokens
        faucet.mintMeTokens(1000);
        gov.endorseProposal(proposalId);
        gov.endorseProposal(proposal1Id);

        gov.activateProposal(proposalId);

        vm.stopBroadcast();
    }
}