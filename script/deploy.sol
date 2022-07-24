// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Kernel.sol";


contract DeployGovernance is Script {
    

    function run() external {
        vm.startBroadcast();

        kernel = new Kernel();
        INSTR = new DefaultInstructions(kernel);
        VOTES = new DefaultVotes(kernel);
        Governance = new Governance(kernel);
        VoteIssuer = new VoteIssuer(kernel);

        

        vm.stopBroadcast();
    }
}