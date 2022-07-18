import {Kernel, Policy, Module, RequestPermissions} from "../../src/Kernel.sol";

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
        returns (RequestPermissions[] memory requests)
    {
        requests = new RequestPermissions[](1);
        requests[0] = RequestPermissions(_toKeycode("MOCKY"), MOCKY.permissionedCall.selector);
    }

    function callPublicFunction() external {
      MOCKY.publicCall();
    }

    function callPermissionedFunction() external onlyIdentity(_toIdentity("tester")) {
      MOCKY.permissionedCall();
    }

}

contract MockModule is Module {
  constructor(Kernel kernel_) Module(kernel_) {}

  uint256 public publicState; 
  uint256 public permissionedState;

  function KEYCODE() public pure override returns (Kernel.Keycode) {
      return _toKeycode("MOCKY");
  }

  function INIT() public override onlyKernel {}

  function publicCall() public {
    publicState++;
  }

  function permissionedCall() public permissioned {
    permissionedState++;
  }
}

contract UpgradedMockModule is Module {

  MockModule _oldModule;
  uint256 public publicState; 
  uint256 public permissionedState;

  constructor(Kernel kernel_, MockModule oldModule_) Module(kernel_) {
    _oldModule = oldModule_;
  }

  function KEYCODE() public pure override returns (Kernel.Keycode) {
      return _toKeycode("MOCKY");
  }

  function INIT() public override onlyKernel {
    permissionedState = _oldModule.permissionedState(); 
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
      return _toKeycode("badkc");
  }

  function INIT() public override onlyKernel {}

  function publicCall() public {
    publicState++;
  }

  function permissionedCall() public permissioned {
    permissionedState++;
  }
}