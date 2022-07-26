// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Kernel.sol";
import "../src/modules/INSTR.sol";
import "../src/modules/VOTES.sol";
import "../src/policies/Governance.sol";
import "../src/policies/VoteIssuer.sol";


contract DeployGovernance is Script {
    Kernel kernel;
    DefaultInstructions INSTR;
    DefaultVotes VOTES;
    Governance governance;
    VoteIssuer issuer;

    function run() external {
        vm.startBroadcast();

        kernel = new Kernel();
        
        INSTR = new DefaultInstructions(kernel);
        VOTES = new DefaultVotes(kernel);
        
        governance = new Governance(kernel);
        issuer = new VoteIssuer(kernel);

        kernel.executeAction(Actions.InstallModule, address(INSTR));
        kernel.executeAction(Actions.InstallModule, address(VOTES));
        kernel.executeAction(Actions.ApprovePolicy, address(governance));
        kernel.executeAction(Actions.ApprovePolicy, address(issuer));
        kernel.executeAction(Actions.ChangeExecutor, address(governance));

        kernel.registerRole(address(0x83D0f479732CC605225263F1AB7016309475aDd9), Role.wrap("voteissuer"));

        vm.stopBroadcast();
    }
}