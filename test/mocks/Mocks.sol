// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {Kernel, Policy, Module, Permissions} from "src/Kernel.sol";

contract MockPolicy is Policy {

    MockModule public MOCKY;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function setDependencies()
        external
        override
        onlyKernel
        returns (Kernel.Keycode[] memory dependencies)
    {
        // declare the number of dependencies
        dependencies = new Kernel.Keycode[](1);

        // 1. Instructions Module
        dependencies[0] = _toKeycode("MOCKY");
        MOCKY = MockModule(getModuleAddress(_toKeycode("MOCKY")));
    }

    function permissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](1);
        requests[0] = Permissions(_toKeycode("MOCKY"), MOCKY.permissionedCall.selector);
    }

    function callPublicFunction() external {
      MOCKY.publicCall();
    }

    // TODO Add identity
    function callPermissionedFunction() external {
      MOCKY.permissionedCall();
    }

}

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

contract InvalidMockModule is Module {
  constructor(Kernel kernel_) Module(kernel_) {}

  uint256 public publicState; 
  uint256 public permissionedState;

  function KEYCODE() public pure override returns (Kernel.Keycode) {
      return Kernel.Keycode.wrap("badkc");
  }

  function publicCall() public {
    publicState++;
  }

  function permissionedCall() public permissioned {
    permissionedState++;
  }
}
