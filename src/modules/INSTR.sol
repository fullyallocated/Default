// SPDX-License-Identifier: AGPL-3.0-only

// [INSTR] The Instructions Module caches and executes batched instructions for protocol upgrades in the Kernel

pragma solidity ^0.8.10;

import {IKernel, Module, Instruction, Actions} from "../Kernel.sol";


contract Instructions is Module {


    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Module Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    constructor(IKernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (bytes5) {
        return "INSTR";
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                              Module Variables                               //
    /////////////////////////////////////////////////////////////////////////////////


    event InstructionsStored(uint256 instructionsId);
    event InstructionsExecuted(uint256 instructionsId);

    error Instructions_Cannot_Be_Empty();
    error Instructions_Module_Must_Be_Last();
    error Address_Is_Not_A_Contract(address target_);
    error Invalid_Keycode(bytes5 keycode_);


    /* Imported from Kernel, just here for reference:

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


    function store(Instruction[] calldata instructions_) external onlyPermittedPolicies returns (uint256) {
        uint256 length = instructions_.length;
        uint256 instructionsId = totalInstructions + 1;
        Instruction[] storage instructions = storedInstructions[instructionsId];

        if (length == 0) revert Instructions_Cannot_Be_Empty();

        for (uint256 i = 0; i < length; i++) {
            Instruction calldata instruction = instructions_[i];
            _ensureContract(instruction.target);

            if (instruction.action == Actions.InstallModule || instruction.action == Actions.UpgradeModule) {
                bytes5 keycode = Module(instruction.target).KEYCODE();
                _ensureValidKeycode(keycode);

                /* 
                CAUTION: Review the conditional below & make sure it's implemented correctly so
                upgrades to the instructions module cannot brick the system

                [INSTR] Module change must be coupled with a "changeExecutor" Instruction
                or the old module will have executor roles while the new modules will be accessed by policies
                Change executor to whitelist of addresses vs. single owner?
                */

                if (keycode == "INSTR" && length - 1 != i) revert Instructions_Module_Must_Be_Last();
            }

            instructions.push(instructions_[i]);
        }
        totalInstructions++;

        emit InstructionsStored(instructionsId);

        return instructionsId;
    }


    function execute(uint256 instructionsId_) external onlyPermittedPolicies {
        Instruction[] memory instructions = storedInstructions[instructionsId_];

        for (uint256 step = 0; step < instructions.length; step++) {
            _kernel.executeAction(instructions[step].action, instructions[step].target);
        }

        emit InstructionsExecuted(instructionsId_);
    }


    /////////////////////////////// INTERNAL FUNCTIONS ////////////////////////////////


    function _ensureContract(address target_) internal view {
        uint256 size;
        assembly {
            size := extcodesize(target_)
        }
        if (size == 0) revert Address_Is_Not_A_Contract(target_);
    }


    function _ensureValidKeycode(bytes5 keycode_) internal pure {
        for (uint256 i = 0; i < 5; i++) {
            bytes1 char = keycode_[i];
            if (char < 0x41 || char > 0x5A)
                revert Invalid_Keycode(keycode_);
            // A-Z only"
        }
    }
}