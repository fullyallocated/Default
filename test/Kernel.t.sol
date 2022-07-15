import {Test} from "forge-std/Test.sol";
import {UserFactory} from "test-utils/UserFactory.sol";
import {Kernel, Module, Policy} from "../src/Kernel.sol";

contract KernelTest is Test {

    Kernel kernel;
    address deployer;
    UserFactory userFactory;

    // initialize correctly

    // identity tests

    // execution tests

    function setUp() public {
      userFactory = new UserFactory();
      address[] memory users = userFactory.create(1);
      users[0] = deployer;

      vm.startPrank(deployer);
      kernel = new Kernel();

      vm.stopPrank();
    }

    function testCorrectness_IntializeKernel() public {
      assertEq(kernel.executor(), deployer);
      assertEq(kernel.admin(), deployer);
      assertEq(kernel.policyPermissions(Policy(address(0)), "XXXXX", bytes4(0)), false);
    }

    function testCorrectness_InstallModule() public {

    }
}

contract PolicyTest is Test {

}

contract ModuleTest is Test {

}
