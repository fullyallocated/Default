// SPDX-License-Identifier: AGPL-3.0-only

// [INSTR] The Instructions Module caches and executes batched instructions for protocol upgrades in the Kernel

pragma solidity ^0.8.13;

import {Kernel, Module, Actions, Instruction} from "src/Kernel.sol";

error INSTR_InstructionsCannotBeEmpty();
error INSTR_InvalidChangeExecutorAction();
error INSTR_InvalidTargetNotAContract();
error INSTR_InvalidModuleKeycode();

contract Instructions is Module {
    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Module Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    Kernel.Role public constant GOVERNOR = Kernel.Role.wrap("INSTR_Governor");

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (Kernel.Keycode) {
        return Kernel.Keycode.wrap("INSTR");
    }

    function ROLES() public pure override returns (Kernel.Role[] memory roles) {
        roles = new Kernel.Role[](1);
        roles[0] = GOVERNOR;
    }

    function INIT() external override {}

    /////////////////////////////////////////////////////////////////////////////////
    //                              Module Variables                               //
    /////////////////////////////////////////////////////////////////////////////////

    event InstructionsStored(uint256 instructionsId);
    event InstructionsExecuted(uint256 instructionsId);

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

    // view function for retrieving a list of instructions in an outside contract
    function getInstructions(uint256 instructionsId_)
        public
        view
        returns (Instruction[] memory)
    {
        return storedInstructions[instructionsId_];
    }

    function store(Instruction[] calldata instructions_)
        external
        onlyRole(GOVERNOR)
        returns (uint256)
    {
        uint256 length = instructions_.length;
        totalInstructions++;

        // initialize an empty list of instructions that will be filled
        Instruction[] storage instructions = storedInstructions[
            totalInstructions
        ];

        // if there are no instructions, throw an error
        if (length == 0) {
            revert INSTR_InstructionsCannotBeEmpty();
        }

        // for each instruction, do the following actions:
        for (uint256 i = 0; i < length; i++) {
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
            } else if (
                instruction.action == Actions.ChangeExecutor && i != length - 1
            ) {
                // throw an error if ChangeExecutor exists and is not the last Action in the instruction llist
                // this exists because if ChangeExecutor is not the last item in the list of instructions
                // the Kernel will not recognize any of the following instructions as valid, since the policy
                // executing the list of instructions no longer has permissions in the Kernel. To avoid this issue
                // and prevent invalid proposals from being saved, we perform this check.

                revert INSTR_InvalidChangeExecutorAction();
            }

            instructions.push(instructions_[i]);
        }

        emit InstructionsStored(totalInstructions);

        return totalInstructions;
    }

    /////////////////////////////// INTERNAL FUNCTIONS ////////////////////////////////

    function _ensureContract(address target_) internal view {
        uint256 size;
        assembly {
            size := extcodesize(target_)
        }
        if (size == 0) revert INSTR_InvalidTargetNotAContract();
    }

    function _ensureValidKeycode(Kernel.Keycode keycode_) internal pure {
        bytes5 unwrapped = Kernel.Keycode.unwrap(keycode_);

        for (uint256 i = 0; i < 5; ) {
            bytes1 char = unwrapped[i];

            if (char < 0x41 || char > 0x5A) revert INSTR_InvalidModuleKeycode(); // A-Z only"

            unchecked {
                i++;
            }
        }
    }
}
