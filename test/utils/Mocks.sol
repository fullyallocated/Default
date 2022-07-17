import {Kernel, Policy, Module} from "../../src/Kernel.sol";

contract MockPolicy is Policy {
  constructor(Kernel kernel_) Policy(kernel_) {}

    MockModule public MOCKY;

    constructor(Kernel kernel_) Policy(kernel_) {}

    function updateDependencies()
        external
        override
        returns (Kernel.Keycode[] memory dependencies)
    {
        // declare the number of dependencies
        dependencies = new Kernel.Keycode[](1);

        // 1. Instructions Module
        dependencies[0] = keycode("MOCKY");
        MOCKY = MockModule(getModuleAddress(keycode("MOCKY")));
    }

    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (RequestPermissions[] memory requests)
    {
        requests = new RequestPermissions[](1);
        requests[0] = RequestPermissions(keycode("MOCKY"), MOCKY.permissionedCall.selector);
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