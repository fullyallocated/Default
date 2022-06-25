// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Kernel, Actions} from "src/Kernel.sol";
import {Instructions} from "src/modules/INSTR.sol";
import {Votes} from "src/modules/VOTES.sol";
import {Governance} from "src/policies/Governance.sol";

//

contract Deploy is Script {

    function run() external {
        vm.startBroadcast();

        // deploy kernel
        Kernel kernel = new Kernel();
        console2.log("Kernel deployed at:", address(kernel));

        // deploy modules
        Instructions instr = new Instructions(kernel);
        Votes votes = new Votes(kernel);

        // deploy policies
        Governance gov = new Governance(kernel);

        // install modules
        kernel.executeAction(Actions.InstallModule, address(instr));
        kernel.executeAction(Actions.InstallModule, address(votes));

        // approve policies
        kernel.executeAction(Actions.ApprovePolicy, address(gov));

        // transfer executive powers to governance
        kernel.executeAction(Actions.ChangeExecutor, address(gov));

        vm.stopBroadcast();
    }
}