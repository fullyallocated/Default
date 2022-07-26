// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;


import "../Kernel.sol";
import { DefaultToken } from "../modules/TOKEN.sol";
import { DefaultVotes } from "../modules/VOTES.sol";


contract Staking is Policy {
    
    DefaultToken public TOKEN;
    DefaultVotes public VOTES;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies() 
        external 
        override 
        onlyKernel
        returns (Keycode[] memory dependencies) 
    {
        dependencies = new Keycode[](2);

        dependencies[0] = toKeycode("TOKEN");
        TOKEN = DefaultToken(getModuleAddress(toKeycode("TOKEN")));
        
        dependencies[1] = toKeycode("VOTES");
        VOTES = DefaultVotes(getModuleAddress(toKeycode("VOTES")));
    }

    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](2);
        requests[0] = Permissions(toKeycode("VOTES"), VOTES.mintTo.selector);
        requests[1] = Permissions(toKeycode("VOTES"), VOTES.burnFrom.selector);
    }

    //////


    function initiateDeposit(uint256 amt_) external {
        // transfer amount
        // record amt + timestamp
    }

    function claimVotes() external {
        // burn the tokens from the contract address
        // mint the votes to the caller
        // wipe the amt + timestamp
    }

    function cancelDeposit() external {
        // return the amt of tokens back to the user
        // wipe the amt + timestamp
    }

    function initiateWithdraw() external {
        // transfer amt
        // record amt + timestamp
    }

    function claimTokens() external {
        // burn the votes from the contract
        // mint the tokens to the caller
        // wipe the amt + timestamp
    }

}