import {Test} from "forge-std/Test.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import {MockModule, MockPolicy} from "./utils/Mocks.sol";
import {Kernel, Module, Policy} from "../src/Kernel.sol";

contract KernelTest is Test {

    Kernel kernel;
    Module module;
    Policy policy;

    address deployer;
    UserFactory userFactory;

    function setUp() public {
      userFactory = new UserFactory();
      address[] memory users = userFactory.create(1);
      users[0] = deployer;

      vm.startPrank(deployer);
      kernel = new Kernel();
      module = new MockModule(kernel);
      policy = new MockPolicy(kernel);

      vm.stopPrank();
    }

    function testCorrectness_IntializeKernel() public {
      policy = Policy(address(0));
      module = Module(address(0));
      Kernel.Keycode keycode = Kernel.Keycode.wrap(0);
      Kernel.Identity identity = Kernel.Identity.wrap(0);

      assertEq(kernel.executor(), deployer);
      assertEq(kernel.admin(), deployer);

      assertEq(kernel.policyPermissions(policy, keycode, bytes4(0)), false);
      assertEq(address(kernel.getModuleForKeycode(keycode)), address(0));
      assertEq(Kernel.Keycode.unwrap(kernel.getKeycodeForModule(module)), bytes5(0));
      assertEq(Kernel.Identity.unwrap(kernel.getIdentityOfAddress(address(0))), bytes10(0));
      assertEq(kernel.getAddressOfIdentity(identity), address(0));
    }

    // Initialize Module
        // - check that it has a keycode
        // - check that it has the right internel variables & configurations
        // - check that its helper functions work

    // Initialize Policy


    // MODULE TESTS:

    // INSTALL MODULE:
        // - check that it enables it as a dependency for Policies
        // - check that it enforces certain permissions for calling

    // UPGRADE MODULE:
        // - check that it can migrate state successfully
        // - check that Policy permissions move over
    // 

    function testCorrectness_InstallModule() public {
      
    }

    function testCorrectness_InstallPolicy() public {
      
    }
}

contract PolicyTest is Test {

}

contract ModuleTest is Test {

}
