import {Kernel, Policy, Module} from "../../src/Kernel.sol";

contract MockPolicy is Policy {
  constructor(Kernel kernel_) Policy(kernel_) {}
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