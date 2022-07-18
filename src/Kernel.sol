// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

// ######################## ~ ERRORS ~ ########################

// AUTH

error Auth_Unauthorized();

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
error Kernel_MaxPoliciesReached();

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

struct Permissions {
    Kernel.Keycode keycode;
    bytes4 funcSelector;
}

// ######################## ~ MODULE ABSTRACT ~ ########################

abstract contract Module {
    event PermissionSet(bytes4 funcSelector_, address policy_, bool permission_);

    Kernel public kernel;

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier permissioned() {
        if (kernel.policyPermissions(msg.sender, KEYCODE(), msg.sig) == false)
          revert Module_PolicyNotAuthorized();
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

    function INIT()
        external
        virtual
    {}
}

abstract contract Policy {
    Kernel public kernel;

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Policy_OnlyKernel(msg.sender);
        _;
    }

    //function configureReads() external virtual onlyKernel {}
    function configureDependencies() 
        external
        virtual
        returns (Kernel.Keycode[] memory dependencies) {}

    function requestPermissions()
        external
        view
        virtual
        returns (Permissions[] memory requests) {}

    function getModuleAddress(Kernel.Keycode keycode_) internal view returns (address) {
        address moduleForKeycode = kernel.getModuleForKeycode(keycode_);

        if (moduleForKeycode == address(0))
            revert Policy_ModuleDoesNotExist(keycode_);

        return moduleForKeycode;
    }

    function _toKeycode(bytes5 keycode_) internal pure returns (Kernel.Keycode) {
        return Kernel.Keycode.wrap(keycode_);
    }

    function _fromKeycode(Kernel.Keycode keycode_) internal pure returns (bytes5) {
        return Kernel.Keycode.unwrap(keycode_);
    }
}

contract Kernel {
    
    // ######################## ~ VARS ~ ########################

    type Keycode is bytes5;
    address public executor;

    // ######################## ~ DEPENDENCY MANAGEMENT ~ ########################

    // Module Management
    mapping(Keycode => address) public getModuleForKeycode; // get contract for module keycode
    mapping(address => Keycode) public getKeycodeForModule; // get module keycode for contract
    mapping(Keycode => address[]) public moduleDependents;

    // Policies are limited to max of 256 due to permissions mapping limitations
    uint256 constant MAX_POLICIES = 256;
    address[] public allPolicies; // Length of this array is number of approved policies
    mapping(address => uint256) public getPolicyIndex; // Reverse lookup for policy index

    // Policy <> Module Permissions
    mapping(address => mapping(Keycode => mapping(bytes4 => bool))) public policyPermissions; // for policy addr, check if they have permission to call the function int he module
    //mapping(Keycode => mapping(bytes4 => bytes32)) public policyPermissions;

    // ######################## ~ EVENTS ~ ########################

    event PermissionsUpdated(
        address indexed policy_,
        Keycode indexed keycode_,
        bytes4 funcSelector_,
        bool indexed granted_
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
        if (action_ == Actions.InstallModule)
            _installModule(target_);
        else if (action_ == Actions.UpgradeModule)
          _upgradeModule(target_);
        else if (action_ == Actions.ApprovePolicy)
          _approvePolicy(target_);
        else if (action_ == Actions.TerminatePolicy)
          _terminatePolicy(target_);
        else if (action_ == Actions.ChangeExecutor)
          executor = target_;
        

        emit ActionExecuted(action_, target_);
    }

    // ######################## ~ KERNEL INTERNAL ~ ########################

    function _installModule(address newModule_) internal {
        Keycode keycode = Module(newModule_).KEYCODE();

        if (getModuleForKeycode[keycode] != address(0))
            revert Kernel_ModuleAlreadyInstalled(keycode);

        getModuleForKeycode[keycode] = newModule_;
        getKeycodeForModule[newModule_] = keycode;
    }

    function _upgradeModule(address newModule_) internal {
        Keycode keycode = Module(newModule_).KEYCODE();
        address oldModule = getModuleForKeycode[keycode];

        if (oldModule == address(0) || oldModule == newModule_)
            revert Kernel_ModuleAlreadyExists(keycode);

        getKeycodeForModule[oldModule] = Keycode.wrap(bytes5(0));
        getKeycodeForModule[newModule_] = keycode;
        getModuleForKeycode[keycode] = newModule_;

        _reconfigurePolicies(keycode);
    }

    function _approvePolicy(address policy_) internal {
        // Grant permissions for policy to access restricted module functions
        Permissions[] memory requests = Policy(policy_).requestPermissions();
        _setPolicyPermissions(policy_, requests, true);

        // Add policy to list of active policies
        uint256 numPolicies = allPolicies.length;

        if (numPolicies == MAX_POLICIES)
            revert Kernel_MaxPoliciesReached();
        else {
            allPolicies.push(policy_);
            // Can use numPolicies since it is now incremented.
            getPolicyIndex[policy_] = numPolicies;
        }

        // Record module dependencies
        Keycode[] memory dependencies = Policy(policy_).configureDependencies();
        uint256 depLength = dependencies.length;

        for (uint256 i; i < depLength;) {
            moduleDependents[dependencies[i]].push(policy_);
            unchecked { ++i; }
        }
    }

    function _terminatePolicy(address policy_) internal {
        Permissions[] memory requests = Policy(policy_).requestPermissions();
        _setPolicyPermissions(policy_, requests, false);

        // Decrement policy count by swapping with last policy and popping array
        uint256 idx = getPolicyIndex[policy_];
        address lastPolicy = allPolicies[allPolicies.length - 1];

        allPolicies[idx] = lastPolicy;
        getPolicyIndex[lastPolicy] = idx;
        allPolicies.pop();
    }

    function _reconfigurePolicies(Keycode keycode_) internal {
        address[] memory dependents = moduleDependents[keycode_];
        uint256 depLength = dependents.length;

        for (uint256 i; i < depLength; ) {
            Policy(dependents[i]).configureDependencies();

            unchecked {
                ++i;
            }
        }
    }

    function _setPolicyPermissions(
        address policy_,
        Permissions[] memory requests_,
        bool grant_
    ) internal {
        uint256 reqLength = requests_.length;
        for (uint256 i = 0; i < reqLength; ) {
            Permissions memory request = requests_[i];

            policyPermissions[policy_][request.keycode][request.funcSelector] = grant_;

            emit PermissionsUpdated(policy_, request.keycode, request.funcSelector, grant_);

            unchecked {
                i++;
            }
        }
    }
}