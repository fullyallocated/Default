// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "src/Kernel.sol";

contract MockPolicy is Policy {
    MockModule public MOCKY;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function configureDependencies()
        external
        override
        returns (Keycode[] memory dependencies)
    {
        MOCKY = MockModule(getModuleAddress(toKeycode("MOCKY")));

        dependencies = new Keycode[](1);
        dependencies[0] = toKeycode("MOCKY");
    }

    function requestPermissions()
        external
        view
        override
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](1);
        requests[0] = Permissions(toKeycode("MOCKY"), MOCKY.permissionedCall.selector);
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

  function KEYCODE() public pure override returns (Keycode) {
      return Keycode.wrap("MOCKY");
  }

  function publicCall() public {
      publicState++;
  }

  function permissionedCall() public permissioned {
      permissionedState++;
  }

}