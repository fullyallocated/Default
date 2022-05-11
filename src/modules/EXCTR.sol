// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import {IKernel, Module, Instruction, Actions} from "../Kernel.sol";

// Processor is the module that stores and executes batched instructions for the kernel
contract Processor is Module {
    error PRCSR_ProposalDoesNotExist();
    error PRCSR_InstructionCannotBeEmpty();
    error PRCSR_ProcessorChangeMustBeLast();
    error PRCSR_AddressIsNotAContract(address target_);
    error PRCSR_InvalidKeycode(bytes5 keycode_);

    /////////////////////////////////////////////////////////////////////////////////
    //                      DefaultOS Module Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    constructor(IKernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (bytes5) {
        return "EXCTR";
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                              System Variables                               //
    /////////////////////////////////////////////////////////////////////////////////

    /* 
    enum Actions {
        ChangeExecutive,
        ApprovePolicy,
        TerminatePolicy,
        InstallSystem,
        UpgradeSystem
    }

    struct Instruction {
        Actions action;
        address target;
    }
    */

    uint256 public totalInstructions;
    mapping(uint256 => Instruction[]) public storedInstructions;

    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Interface                                //
    /////////////////////////////////////////////////////////////////////////////////

    event InstructionsStored(uint256 instructionsId);
    event InstructionsExecuted(uint256 instructionsId);

    function storeInstructions(Instruction[] calldata instructions_)
        external
        onlyPermitted
        returns (uint256)
    {
        uint256 length = instructions_.length;
        uint256 instructionsId = totalInstructions + 1;
        Instruction[] storage instructions = storedInstructions[instructionsId];

        if (length != 0) revert PRCSR_InstructionCannotBeEmpty();

        // @TODO use u256
        for (uint256 i = 0; i < length; i++) {
            Instruction calldata instruction = instructions_[i];
            _ensureContract(instruction.target);

            if (
                instruction.action == Actions.InstallModule ||
                instruction.action == Actions.UpgradeModule
            ) {
                bytes5 keycode = Module(instruction.target).KEYCODE();
                _ensureValidKeycode(keycode);

                if (keycode == "PRCSR" && length - 1 != i)
                    revert PRCSR_ProcessorChangeMustBeLast();
            }

            instructions.push(instructions_[i]);
        }
        totalInstructions++;

        emit InstructionsStored(instructionsId);

        return instructionsId;
    }

    // TODO Add timelock
    function executeInstructions(uint256 instructionsId_)
        external
        onlyPermitted
    {
        Instruction[] storage proposal = storedInstructions[instructionsId_];

        if (proposal.length > 0) revert PRCSR_ProposalDoesNotExist();

        for (uint256 step = 0; step < proposal.length; step++) {
            _kernel.executeAction(proposal[step].action, proposal[step].target);
        }

        emit InstructionsExecuted(instructionsId_);
    }

    /////////////////////////////// INTERNAL FUNCTIONS ////////////////////////////////

    function _ensureContract(address target_) internal view {
        uint256 size;
        assembly {
            size := extcodesize(target_)
        }
        if (size == 0) revert PRCSR_AddressIsNotAContract(target_);
    }

    function _ensureValidKeycode(bytes5 keycode_) internal pure {
        for (uint256 i = 0; i < 5; i++) {
            bytes1 char = keycode_[i];
            if (char < 0x41 || char > 0x5A)
                revert PRCSR_InvalidKeycode(keycode_);
            // A-Z only"
        }
    }
}