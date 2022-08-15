// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/Kernel.sol";
import "../src/modules/INSTR.sol";
import "../src/modules/VOTES.sol";
import "../src/modules/TRSRY.sol";
import "../src/policies/Governance.sol";
import "../src/policies/Bond.sol";


contract Deploy is Script {
    Kernel kernel;
    DefaultInstructions INSTR;
    DefaultVotes VOTES;
    DefaultTreasury TRSRY;
    Governance governance;
    Bond bond;

    ERC20 constant DAI = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); // DAI on Arbitrum

    function run() external {
        vm.startBroadcast();

        ERC20[] memory approvedTokens = new ERC20[](1);
        approvedTokens[0] = ERC20(DAI);

        kernel = new Kernel();

        INSTR = new DefaultInstructions(kernel);
        VOTES = new DefaultVotes(kernel);
        TRSRY = new DefaultTreasury(kernel, approvedTokens);
        
        governance = new Governance(kernel);
        bond = new Bond(kernel, DAI);

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