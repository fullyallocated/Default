// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../Kernel.sol";
import { DefaultVotes } from "../modules/VOTES.sol";

contract VoteIssuer is Policy {
    
    DefaultVotes public VOTES;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies() 
        external 
        override 
        onlyKernel
        returns (Keycode[] memory dependencies) 
    {
        dependencies = new Keycode[](1);
        
        dependencies[0] = toKeycode("VOTES");
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


    function mint(address wallet_, uint256 amt_) external onlyRole("voteissuer") {
        VOTES.mintTo(wallet_, amt_);
    }

    function burn(address wallet_, uint256 amt_) external onlyRole("voteissuer") {
        VOTES.burnFrom(wallet_, amt_);
    }

}