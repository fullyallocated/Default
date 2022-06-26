// SPDX-License-Identifier: AGPL-3.0-only

// The Proposal Policy submits & activates instructions in a INSTR module

pragma solidity ^0.8.13;

import {Token} from "src/modules/TOKEN.sol";
import {Kernel, Policy, Module} from "src/Kernel.sol";


contract Faucet is Policy {

    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    Token public TOKEN;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureReads() external override {
        TOKEN = Token(getModuleAddress("TOKEN"));
    }

    function requestRoles()
        external
        view
        override
        onlyKernel
        returns (Kernel.Role[] memory roles)
    {
        roles = new Kernel.Role[](1);
        roles[0] = TOKEN.ISSUER();
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Variables                                //
    /////////////////////////////////////////////////////////////////////////////////

    function mintMeTokens(uint256 amt_) external {
      TOKEN.mintTo(msg.sender, amt_);
    }
}