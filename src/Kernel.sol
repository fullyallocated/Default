// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "src/utils/KernelUtils.sol";

// ######################## ~ ERRORS ~ ########################

// MODULE

error Module_PolicyNotAuthorized(address policy_);

// POLICY

error Policy_OnlyKernel(address caller_);
<<<<<<< HEAD
error Policy_OnlyIdentity(Kernel.Identity identity_);
=======
error Policy_OnlyRole(Role role_);
error Policy_ModuleDoesNotExist(Keycode keycode_);
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927

// KERNEL

error Kernel_OnlyExecutor(address caller_);
error Kernel_OnlyAdmin(address caller_);
<<<<<<< HEAD
error Kernel_IdentityAlreadyExists(Kernel.Identity identity_);
error Kernel_InvalidIdentity(Kernel.Identity identity_);
error Kernel_ModuleAlreadyInstalled(Kernel.Keycode module_);
error Kernel_ModuleAlreadyExists(Kernel.Keycode module_);
=======
error Kernel_ModuleAlreadyInstalled(Keycode module_);
error Kernel_InvalidModuleUpgrade(Keycode module_);
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
error Kernel_PolicyAlreadyApproved(address policy_);
error Kernel_PolicyNotApproved(address policy_);
error Kernel_AddressAlreadyHasRole(address addr_, Role role_);
error Kernel_AddressDoesNotHaveRole(address addr_, Role role_);
error Kernel_RoleDoesNotExist(Role role_);
error Kernel_InvalidTargetNotAContract(address target_);
error Kernel_InvalidKeycode(Keycode keycode_);
error Kernel_InvalidRole(Role role_);

// ######################## ~ GLOBAL TYPES ~ ########################

enum Actions {
    InstallModule,
    UpgradeModule,
    ApprovePolicy,
    TerminatePolicy,
    ChangeExecutor,
    ChangeAdmin
}

struct Instruction {
    Actions action;
    address target;
}

struct Permissions {
    Keycode keycode;
    bytes4 funcSelector;
}

type Keycode is bytes5;
type Role is bytes32;

// ######################## ~ MODULE ABSTRACT ~ ########################

abstract contract Module {
    event PermissionSet(bytes4 funcSelector_, address policy_, bool permission_);

    Kernel public kernel;

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

<<<<<<< HEAD
    modifier permissioned(bytes4 funcSelector_) {
      Kernel.Keycode keycode = KEYCODE();
      if (kernel.policyPermissions(Policy(msg.sender), keycode, funcSelector_) == false) {
        revert Module_PolicyNotAuthorized();
      }
      _;
=======
    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Policy_OnlyKernel(msg.sender);
        _;
    }

    modifier permissioned() {
        if (!kernel.modulePermissions(KEYCODE(), Policy(msg.sender), msg.sig))
            revert Module_PolicyNotAuthorized(msg.sender);
        _;
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
    }

    function KEYCODE() public pure virtual returns (Keycode);

    /// @notice Specify which version of a module is being implemented.
    /// @dev Minor version change retains interface. Major version upgrade indicates
    /// @dev breaking change to the interface.
    function VERSION() external pure virtual returns (uint8 major, uint8 minor) {}

    /// @notice Initialization function for the module.
    /// @dev This function is called when the module is installed or upgraded by the kernel.
    /// @dev Used to encompass any upgrade logic. Must be gated by onlyKernel.
    function INIT() external virtual onlyKernel {}
}

abstract contract Policy {

    Kernel public kernel;
<<<<<<< HEAD
    
    mapping(Kernel.Keycode => bool) public hasDependency;

=======
    bool public isActive;
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Policy_OnlyKernel(msg.sender);
        _;
    }

<<<<<<< HEAD
    modifier onlyIdentity(Kernel.Identity identity_) {
        if(Kernel.Identity.unwrap(kernel.getIdentityOfAddress(msg.sender)) != Kernel.Identity.unwrap(identity_)) revert Policy_OnlyIdentity(identity_);
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
=======
    modifier onlyRole(bytes32 role_) {
        Role role = toRole(role_);
        if(!kernel.hasRole(msg.sender, role))
            revert Policy_OnlyRole(role);
        _;
    }

    function configureDependencies() external virtual returns (Keycode[] memory dependencies) {}

    function requestPermissions() external view virtual returns (Permissions[] memory requests) {}

    function getModuleAddress(Keycode keycode_) internal view returns (address) {
        address moduleForKeycode = address(kernel.getModuleForKeycode(keycode_));
        if (moduleForKeycode == address(0)) revert Policy_ModuleDoesNotExist(keycode_);
        return moduleForKeycode;
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
    }

    /// @notice Function to let kernel grant or revoke active status
    function setActiveStatus(bool activate_) external onlyKernel {
        isActive = activate_;
    }
}

contract Kernel {
    // ######################## ~ VARS ~ ########################
<<<<<<< HEAD

    type Keycode is bytes5;
    type Identity is bytes10;
=======
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
    address public executor;
    address public admin;

    // ######################## ~ DEPENDENCY MANAGEMENT ~ ########################

<<<<<<< HEAD
    mapping(Policy => mapping(Keycode => mapping(bytes4 => bool))) public policyPermissions; // for policy addr, check if they have permission to call the function
    Policy[] public allPolicies; // all the approved policies in the kernel

    mapping(Keycode => Module) public getModuleForKeycode; // get contract for module keycode
    mapping(Module => Keycode) public getKeycodeForModule; // get module keycode for contract
    
    mapping(address => Identity) public getIdentityOfAddress;
    mapping(Identity => address) public getAddressOfIdentity;
=======
    // Module Management
    mapping(Keycode => Module) public getModuleForKeycode; // get contract for module keycode
    mapping(Module => Keycode) public getKeycodeForModule; // get module keycode for contract
    
    // Module dependents data. Manages module dependencies for policies
    mapping(Keycode => Policy[]) public moduleDependents;
    mapping(Keycode => mapping(Policy => uint256)) public getDependentIndex;

    // Module <> Policy Permissions. Policy -> Keycode -> Function Selector -> Permission
    mapping(Keycode => mapping(Policy => mapping(bytes4 => bool))) public modulePermissions; // for policy addr, check if they have permission to call the function int he module
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927

    // List of all active policies
    Policy[] public activePolicies;
    // Reverse lookup for policy index
    mapping(Policy => uint256) public getPolicyIndex;

    // Policy roles data
    mapping(address => mapping(Role => bool)) public hasRole;
    mapping(Role => bool) public isRole;

    // ######################## ~ EVENTS ~ ########################

<<<<<<< HEAD
    event PermissionsUpated(
        Policy indexed policy_,
        Keycode indexed keycode_,
        bytes4 indexed funcSelector_,
        bool granted_
=======
    event PermissionsUpdated(
        Keycode indexed keycode_,
        Policy indexed policy_,
        bytes4 funcSelector_,
        bool indexed granted_
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
    );
    event RoleGranted(Role indexed role_, address indexed addr_);
    event RoleRevoked(Role indexed role_, address indexed addr_);
    event ActionExecuted(Actions indexed action_, address indexed target_);

    // ######################## ~ BODY ~ ########################

    constructor() {
        executor = msg.sender;
        admin = msg.sender;
    }

    // ######################## ~ MODIFIERS ~ ########################

    // Role reserved for governor or any executing address
    modifier onlyExecutor() {
        if (msg.sender != executor) revert Kernel_OnlyExecutor(msg.sender);
        _;
    }

<<<<<<< HEAD
=======
    // Role for managing policy roles
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Kernel_OnlyAdmin(msg.sender);
        _;
    }

    // ######################## ~ KERNEL INTERFACE ~ ########################

<<<<<<< HEAD

    function registerIdentity(address address_, Identity identity_)
      external
      onlyAdmin
    {
      if (Identity.unwrap(getIdentityOfAddress[address_]) != bytes10(0) ) revert Kernel_IdentityAlreadyExists(identity_);
      for (uint256 i; i < 10;) {
        bytes1 char = Identity.unwrap(identity_)[i];
        if (!(char >= 0x61 && char <= 0x7A)) revert Kernel_InvalidIdentity(identity_);  // a-z only
      }
      getIdentityOfAddress[address_] = identity_;
      getAddressOfIdentity[identity_] = address_;
    }


    function revokeIdentity(Identity identity_)
      external
      onlyAdmin
    {
      address addressOfIdentity = getAddressOfIdentity[identity_];
      if (addressOfIdentity == address(0)) revert Kernel_IdentityAlreadyExists(identity_);
      getAddressOfIdentity[identity_] = address(0);
      getIdentityOfAddress[addressOfIdentity] = Identity.wrap(bytes10(0));
    }


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
=======
    function executeAction(Actions action_, address target_) external onlyExecutor {
        if (action_ == Actions.InstallModule) {
            ensureContract(target_);
            ensureValidKeycode(Module(target_).KEYCODE());

            _installModule(Module(target_));
        } else if (action_ == Actions.UpgradeModule) {
            ensureContract(target_);
            ensureValidKeycode(Module(target_).KEYCODE());

            _upgradeModule(Module(target_));
        } else if (action_ == Actions.ApprovePolicy) {
            ensureContract(target_);

            _approvePolicy(Policy(target_));
        } else if (action_ == Actions.TerminatePolicy) {
            ensureContract(target_);

>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
            _terminatePolicy(Policy(target_));
        } else if (action_ == Actions.ChangeExecutor) {
            executor = target_;
        } else if (action_ == Actions.ChangeAdmin) {
            admin = target_;
        }

        emit ActionExecuted(action_, target_);
    }

    // ######################## ~ KERNEL INTERNAL ~ ########################

    function _installModule(Module newModule_) internal {
<<<<<<< HEAD
        Keycode keycode = Module(newModule_).KEYCODE();

        // @NOTE check newModule_ != 0
=======
        Keycode keycode = newModule_.KEYCODE();

>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
        if (address(getModuleForKeycode[keycode]) != address(0))
            revert Kernel_ModuleAlreadyInstalled(keycode);

        getModuleForKeycode[keycode] = newModule_;
        getKeycodeForModule[newModule_] = keycode;

        newModule_.INIT();
    }

    function _upgradeModule(Module newModule_) internal {
        Keycode keycode = newModule_.KEYCODE();
        Module oldModule = getModuleForKeycode[keycode];

<<<<<<< HEAD
        if (address(oldModule) == address(0) || address(oldModule) == address(newModule_))
            revert Kernel_ModuleAlreadyExists(keycode);
=======
        if (address(oldModule) == address(0) || oldModule == newModule_)
            revert Kernel_InvalidModuleUpgrade(keycode);
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927

        getKeycodeForModule[oldModule] = Keycode.wrap(bytes5(0));
        getKeycodeForModule[newModule_] = keycode;
        getModuleForKeycode[keycode] = newModule_;

<<<<<<< HEAD
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
=======
        newModule_.INIT();

        _reconfigurePolicies(keycode);
    }

    function _approvePolicy(Policy policy_) internal {
        if (policy_.isActive()) revert Kernel_PolicyAlreadyApproved(address(policy_));

        // Grant permissions for policy to access restricted module functions
        Permissions[] memory requests = policy_.requestPermissions();
        _setPolicyPermissions(policy_, requests, true);
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927

        // Add policy to list of active policies
        activePolicies.push(policy_);
        getPolicyIndex[policy_] = activePolicies.length - 1;

        // Record module dependencies
        Keycode[] memory dependencies = policy_.configureDependencies();
        uint256 depLength = dependencies.length;

        for (uint256 i; i < depLength; ) {
            Keycode keycode = dependencies[i];

            moduleDependents[keycode].push(policy_);
            getDependentIndex[keycode][policy_] = moduleDependents[keycode].length - 1;

            unchecked {
                ++i;
            }
        }

        // Set policy status to active
        policy_.setActiveStatus(true);
    }

    function _terminatePolicy(Policy policy_) internal {
<<<<<<< HEAD

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
=======
        if (!policy_.isActive()) revert Kernel_PolicyNotApproved(address(policy_));

        // Revoke permissions
        Permissions[] memory requests = policy_.requestPermissions();
        _setPolicyPermissions(policy_, requests, false);

        // Remove policy from all policy data structures
        uint256 idx = getPolicyIndex[policy_];
        Policy lastPolicy = activePolicies[activePolicies.length - 1];

        activePolicies[idx] = lastPolicy;
        activePolicies.pop();
        getPolicyIndex[lastPolicy] = idx;
        delete getPolicyIndex[policy_];

        // Remove policy from module dependents
        _pruneFromDependents(policy_);

        // Set policy status to inactive
        policy_.setActiveStatus(false);
    }

    function _reconfigurePolicies(Keycode keycode_) internal {
        Policy[] memory dependents = moduleDependents[keycode_];
        uint256 depLength = dependents.length;

        for (uint256 i; i < depLength; ) {
            dependents[i].configureDependencies();

            unchecked {
                ++i;
            }
        }
    }

    function _setPolicyPermissions(
        Policy policy_,
        Permissions[] memory requests_,
        bool grant_
    ) internal {
        uint256 reqLength = requests_.length;
        for (uint256 i = 0; i < reqLength; ) {
            Permissions memory request = requests_[i];
            modulePermissions[request.keycode][policy_][request.funcSelector] = grant_;

            emit PermissionsUpdated(request.keycode, policy_, request.funcSelector, grant_);

            unchecked {
                ++i;
            }
        }
    }

    function _pruneFromDependents(Policy policy_) internal {
        Keycode[] memory dependencies = policy_.configureDependencies();
        uint256 depcLength = dependencies.length;

        for (uint256 i; i < depcLength; ) {
            Keycode keycode = dependencies[i];
            Policy[] storage dependents = moduleDependents[keycode];

            uint256 origIndex = getDependentIndex[keycode][policy_];
            Policy lastPolicy = dependents[dependents.length - 1];

            // Swap with last and pop
            dependents[origIndex] = lastPolicy;
            dependents.pop();

            // Record new index and delete terminated policy index
            getDependentIndex[keycode][lastPolicy] = origIndex;
            delete getDependentIndex[keycode][policy_];

            unchecked {
                ++i;
>>>>>>> 12e4a1ad502aa29e0ad779ae347810b1cf0b1927
            }
        }
    }

    // TODO
    function grantRole(Role role_, address addr_) public onlyAdmin {
        if (hasRole[addr_][role_]) revert Kernel_AddressAlreadyHasRole(addr_, role_);

        ensureValidRole(role_);
        if (!isRole[role_]) isRole[role_] = true;

        hasRole[addr_][role_] = true;

        emit RoleGranted(role_, addr_);
    }

    // TODO
    function revokeRole(Role role_, address addr_) public onlyAdmin {
        if (!isRole[role_]) revert Kernel_RoleDoesNotExist(role_);
        if (!hasRole[addr_][role_]) revert Kernel_AddressDoesNotHaveRole(addr_, role_);

        hasRole[addr_][role_] = false;

        emit RoleRevoked(role_, addr_);
    }
}
