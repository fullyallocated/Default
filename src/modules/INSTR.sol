// SPDX-License-Identifier: AGPL-3.0-only

// [INSTR] The Instructions Module caches and executes batched instructions for protocol upgrades in the Kernel

pragma solidity ^0.8.15;

import { Kernel, Module, Keycode, Instruction, Actions } from "src/Kernel.sol";

interface IDefaultInstructions {

    event InstructionsStored(uint256 instructionsId);

    error INSTR_InstructionsCannotBeEmpty();
    error INSTR_InvalidChangeExecutorAction();
    error INSTR_InvalidTargetNotAContract();
    error INSTR_InvalidModuleKeycode();
}


contract DefaultInstructions is Module, IDefaultInstructions {

    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Module Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (Keycode) {
        return Keycode.wrap("INSTR");
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                              Module Variables                               //
    /////////////////////////////////////////////////////////////////////////////////

    uint256 public totalInstructions;
    mapping(uint256 => Instruction[]) public storedInstructions;

    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Interface                                //
    /////////////////////////////////////////////////////////////////////////////////

    // view function for retrieving a list of instructions in an outside contract
    function getInstructions(uint256 instructionsId_) public view returns (Instruction[] memory) {
        return storedInstructions[instructionsId_];
    }

    function store(Instruction[] calldata instructions_) external permissioned returns (uint256) {
        uint256 length = instructions_.length;
        uint256 instructionsId = ++totalInstructions;

        // initialize an empty list of instructions that will be filled
        Instruction[] storage instructions = storedInstructions[instructionsId];

        // if there are no instructions, throw an error
        if (length == 0) {
            revert INSTR_InstructionsCannotBeEmpty();
        }

        // for each instruction, do the following actions:
        for (uint256 i; i < length; ) {
            // get the instruction
            Instruction calldata instruction = instructions_[i];

            // check the address that the instruction is being performed on is a contract (bytecode size > 0)
            _ensureContract(instruction.target);

            // if the instruction deals with a module, make sure the module has a valid keycode (UPPERCASE A-Z ONLY)
            if (
                instruction.action == Actions.InstallModule ||
                instruction.action == Actions.UpgradeModule
            ) {
                Module module = Module(instruction.target);
                _ensureValidKeycode(module.KEYCODE());
            } else if (instruction.action == Actions.ChangeExecutor && i != length - 1) {
                // throw an error if ChangeExecutor exists and is not the last Action in the instruction llist
                // this exists because if ChangeExecutor is not the last item in the list of instructions
                // the Kernel will not recognize any of the following instructions as valid, since the policy
                // executing the list of instructions no longer has permissions in the Kernel. To avoid this issue
                // and prevent invalid proposals from being saved, we perform this check.

                revert INSTR_InvalidChangeExecutorAction();
            }

            instructions.push(instructions_[i]);
            unchecked {
                ++i;
            }
        }

        emit InstructionsStored(instructionsId);

        return instructionsId;
    }

    /////////////////////////////// INTERNAL FUNCTIONS ////////////////////////////////

    function _ensureContract(address target_) internal view {
        uint256 size;
        assembly {
            size := extcodesize(target_)
        }
        if (size == 0) revert INSTR_InvalidTargetNotAContract();
    }

    function _ensureValidKeycode(Keycode keycode_) internal pure {
        bytes5 unwrapped = Keycode.unwrap(keycode_);

        for (uint256 i = 0; i < 5; ) {
            bytes1 char = unwrapped[i];

            if (char < 0x41 || char > 0x5A) revert INSTR_InvalidModuleKeycode(); // A-Z only"

            unchecked {
                i++;
            }
        }
    }
}
