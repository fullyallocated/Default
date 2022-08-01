// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";
// import "../src/Kernel.sol";
// import "../src/modules/INSTR.sol";
// import "../src/modules/VOTES.sol";
// import "../src/policies/Governance.sol";
// import "../src/policies/VoteIssuer.sol";


// contract DeployGovernance is Script {
//     Kernel kernel;
//     DefaultInstructions INSTR;
//     DefaultVotes VOTES;
//     Governance governance;

//     function run() external {
//         vm.startBroadcast();

//         kernel = new Kernel();
        
//         INSTR = new DefaultInstructions(kernel);
//         VOTES = new DefaultVotes(kernel);
        
//         governance = new Governance(kernel);

//         kernel.executeAction(Actions.InstallModule, address(INSTR));
//         kernel.executeAction(Actions.InstallModule, address(VOTES));
//         kernel.executeAction(Actions.ApprovePolicy, address(governance));
//         kernel.executeAction(Actions.ChangeExecutor, address(governance));

//         vm.stopBroadcast();
//     }
// }