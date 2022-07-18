// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {Kernel, Module} from "src/Kernel.sol";

contract MockModule is Module {
  constructor(Kernel kernel_) Module(kernel_) {}

  uint256 public publicState; 
  uint256 public permissionedState;

  function KEYCODE() public pure override returns (Kernel.Keycode) {
      return Kernel.Keycode.wrap("MOCKY");
  }

  function publicCall() public {
    publicState++;
  }

  function permissionedCall() public permissioned {
    permissionedState++;
  }

}