// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

// ######################## ~ ERRORS ~ ########################

// MODULE

error Module_PolicyNotAuthorized();

// POLICY

error Policy_ModuleDoesNotExist(Kernel.Keycode keycode_);
error Policy_OnlyKernel(address caller_);

// KERNEL

error Kernel_OnlyExecutor(address caller_);
error Kernel_ModuleAlreadyInstalled(Kernel.Keycode module_);
error Kernel_ModuleAlreadyExists(Kernel.Keycode module_);
error Kernel_PolicyAlreadyApproved(address policy_);
error Kernel_PolicyNotApproved(address policy_);

// ######################## ~ GLOBAL TYPES ~ ########################

enum Actions {
    InstallModule,
    UpgradeModule,
    ApprovePolicy,
    TerminatePolicy,
    ChangeExecutor
}

struct Instruction {
    Actions action;
    address target;
}

struct RequestPermissions {
    Kernel.Keycode keycode;
    bytes4 funcSelector;
}

// ######################## ~ MODULE ABSTRACT ~ ########################

abstract contract Module {
    Kernel public kernel;

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier permissioned(bytes4 funcSelector_) {
      Kernel.Keycode keycode = KEYCODE();
      if (kernel.policyPermissions(Policy(msg.sender), keycode, funcSelector_) == false) {
        revert Module_PolicyNotAuthorized();
      }
      _;
    }

    function KEYCODE() public pure virtual returns (Kernel.Keycode);

    /// @notice Specify which version of a module is being implemented.
    /// @dev Minor version change retains interface. Major version upgrade indicates
    ///      breaking change to the interface.
    function VERSION()
        external
        pure
        virtual
        returns (uint8 major, uint8 minor)
    {}
}

abstract contract Policy {
    Kernel public kernel;
    
    mapping(Kernel.Keycode => bool) public hasDependency;


    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Policy_OnlyKernel(msg.sender);
        _;
    }

    function _toKeycode(bytes5 keycode_) internal pure returns (Kernel.Keycode keycode) {
        keycode = Kernel.Keycode.wrap(keycode_);
    }

    function registerDependency(Kernel.Keycode keycode_) 
      external 
      onlyKernel  
    {
        hasDependency[keycode_] = true;
    }

    function updateDependencies() 
      external 
      virtual 
      onlyKernel 
      returns (Kernel.Keycode[] memory dependencies) 
    {}

    function requestPermissions()
        external
        view
        virtual
        returns (RequestPermissions[] memory requests)
    {}

    function getModuleAddress(Kernel.Keycode keycode_) internal view returns (address) {
        address moduleAddress = address(kernel.getModuleForKeycode(keycode_));

        if (moduleAddress == address(0))
            revert Policy_ModuleDoesNotExist(keycode_);

        return moduleAddress;
    }
}

contract Kernel {
    // ######################## ~ VARS ~ ########################

    type Keycode is bytes5;
    address public executor;

    // ######################## ~ DEPENDENCY MANAGEMENT ~ ########################

    mapping(Keycode => Module) public getModuleForKeycode; // get contract for module keycode
    mapping(Module => Keycode) public getKeycodeForModule; // get module keycode for contract
    mapping(Policy => mapping(Keycode => mapping(bytes4 => bool))) public policyPermissions; // for policy addr, check if they have permission to call the function
    Policy[] public allPolicies; // all the approved policies in the kernel


    // ######################## ~ EVENTS ~ ########################

    event PermissionsUpated(
        Policy indexed policy_,
        Keycode indexed keycode_,
        bytes4 indexed funcSelector_,
        bool granted_
    );

    event ActionExecuted(Actions indexed action_, address indexed target_);

    // ######################## ~ BODY ~ ########################

    constructor() {
        executor = msg.sender;
    }

    // ######################## ~ MODIFIERS ~ ########################

    modifier onlyExecutor() {
        if (msg.sender != executor) revert Kernel_OnlyExecutor(msg.sender);
        _;
    }

    // ######################## ~ KERNEL INTERFACE ~ ########################

    function executeAction(Actions action_, address target_)
        external
        onlyExecutor
    {
        if (action_ == Actions.InstallModule) {
            _installModule(Module(target_));
        } else if (action_ == Actions.UpgradeModule) {
            _upgradeModule(Module(target_));
        } else if (action_ == Actions.ApprovePolicy) {
            _approvePolicy(Policy(target_));
        } else if (action_ == Actions.TerminatePolicy) {
            _terminatePolicy(Policy(target_));
        } else if (action_ == Actions.ChangeExecutor) {
            executor = target_;
        }

        emit ActionExecuted(action_, target_);
    }

    // ######################## ~ KERNEL INTERNAL ~ ########################

    function _installModule(Module newModule_) internal {
        Keycode keycode = Module(newModule_).KEYCODE();

        // @NOTE check newModule_ != 0
        if (address(getModuleForKeycode[keycode]) != address(0))
            revert Kernel_ModuleAlreadyInstalled(keycode);

        getModuleForKeycode[keycode] = newModule_;
        getKeycodeForModule[newModule_] = keycode;
    }

    function _upgradeModule(Module newModule_) internal {
        Keycode keycode = newModule_.KEYCODE();
        Module oldModule = getModuleForKeycode[keycode];

        if (address(oldModule) == address(0) || address(oldModule) == address(newModule_))
            revert Kernel_ModuleAlreadyExists(keycode);

        getKeycodeForModule[oldModule] = Keycode.wrap(bytes5(0));
        getKeycodeForModule[newModule_] = keycode;
        getModuleForKeycode[keycode] = newModule_;

        // go through each policy in the Kernel and update its dependencies if they include the module
        for (uint i; i < allPolicies.length; ) {
            Policy policy = allPolicies[i];
            if (policy.hasDependency(keycode)) {
                policy.updateDependencies();
            }
        }
    }

    function _approvePolicy(Policy policy_) internal {
        policy_.updateDependencies();
        RequestPermissions[] memory requests = policy_.requestPermissions();
        
        for (uint256 i = 0; i < requests.length; ) {
            RequestPermissions memory request = requests[i];

            policyPermissions[policy_][request.keycode][request.funcSelector] = true;

            policy_.registerDependency(request.keycode);

            emit PermissionsUpated(policy_, request.keycode, request.funcSelector, true);

            unchecked { i++; }

        }

        allPolicies.push(policy_);
    }

    function _terminatePolicy(Policy policy_) internal {

        RequestPermissions[] memory requests = Policy(policy_).requestPermissions();

        for (uint256 i = 0; i < requests.length; ) {
            RequestPermissions memory request = requests[i];

            policyPermissions[policy_][request.keycode][request.funcSelector] = false;

            emit PermissionsUpated(policy_, request.keycode, request.funcSelector, false);

            unchecked { i++; }
        }

        // swap the current policy (terminated) with the last policy in the list and remove the last item
        uint numPolicies = allPolicies.length;

        for (uint j; j < numPolicies;) {
            if (allPolicies[j] == policy_) {
              allPolicies[j] = allPolicies[numPolicies - 1]; 
              allPolicies.pop();
            }
        }
    }
}