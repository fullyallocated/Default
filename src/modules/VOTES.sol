// SPDX-License-Identifier: AGPL-3.0-only

// [INSTR] The Instructions Module caches and executes batched instructions for protocol upgrades in the Kernel

pragma solidity ^0.8.10;

import {IKernel, Module} from "../Kernel.sol";
import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";

contract Votes is Module, ERC20("Voting Tokens", "VOTES", 18) {

  constructor(IKernel kernel_) Module(kernel_) {}

  function KEYCODE() public pure override returns (bytes5) {
      return "VOTES";
  }


}