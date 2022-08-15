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

    ERC20 constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    function run() external {
        vm.startBroadcast();

        kernel = new Kernel();
        
        INSTR = new DefaultInstructions(kernel);
        VOTES = new DefaultVotes(kernel);
        TRSRY = new DefaultTreasury(kernel, DAI);
        
        governance = new Governance(kernel);
        voteIssuer = new VoteIssuer(kernel);

        kernel.executeAction(Actions.InstallModule, address(INSTR));
        kernel.executeAction(Actions.InstallModule, address(VOTES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));

        kernel.executeAction(Actions.ActivatePolicy, address(governance));
        kernel.executeAction(Actions.ActivatePolicy, address(bond));

        kernel.executeAction(Actions.ChangeAdmin, address(0));
        kernel.executeAction(Actions.ChangeExecutor, address(governance));


        vm.stopBroadcast();
    }
}