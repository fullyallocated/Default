// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

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
    DefaultTreasury TRSRY;
    Governance governance;
    Bond bond;

    function run() external {
        vm.startBroadcast();

        kernel = new Kernel();
        
        INSTR = new DefaultInstructions(kernel);
        VOTES = new DefaultVotes(kernel);
        
        governance = new Governance(kernel);
        voteIssuer = new VoteIssuer(kernel);

        kernel.executeAction(Actions.InstallModule, address(INSTR));
        kernel.executeAction(Actions.InstallModule, address(VOTES));
        kernel.executeAction(Actions.ActivatePolicy, address(governance));
        kernel.executeAction(Actions.ActivatePolicy, address(voteIssuer));
        kernel.executeAction(Actions.ChangeExecutor, address(governance));

        kernel.grantRole(Role.wrap("voteissuer"), 0x83D0f479732CC605225263F1AB7016309475aDd9);

        vm.stopBroadcast();
    }
}