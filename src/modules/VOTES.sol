// SPDX-License-Identifier: AGPL-3.0-only

// [INSTR] The Instructions Module caches and executes batched instructions for protocol upgrades in the Kernel

pragma solidity ^0.8.10;

import {IKernel, Module} from "../Kernel.sol";
import ERC20 from "@solmate/token";

contract VOTES is Module, ERC20("staked votes", VOTES) {

  

}