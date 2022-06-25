// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Kernel, Module} from "src/Kernel.sol";

// ERRORS
error TRSRY_NotReserve();
error TRSRY_NotApproved();
error TRSRY_PolicyStillActive();

contract Treasury is Module {
    using SafeTransferLib for ERC20;

    event ApprovedForWithdrawal(
        address indexed policy_,
        ERC20 indexed token_,
        uint256 amount_
    );
    event Withdrawal(
        address indexed policy_,
        address indexed withdrawer_,
        ERC20 indexed token_,
        uint256 amount_
    );
    event ApprovalRevoked(address indexed policy_, ERC20[] tokens_);
    event DebtIncurred(
        ERC20 indexed token_,
        address indexed policy_,
        uint256 amount_
    );
    event DebtRepaid(
        ERC20 indexed token_,
        address indexed policy_,
        uint256 amount_
    );
    event DebtCleared(
        ERC20 indexed token_,
        address indexed policy_,
        uint256 amount_
    );
    event DebtSet(
        ERC20 indexed token_,
        address indexed policy_,
        uint256 amount_
    );

    Kernel.Role public constant APPROVER = Kernel.Role.wrap("TRSRY_Approver");

    // user -> reserve -> amount. Infinite approval is max(uint256).
    mapping(address => mapping(ERC20 => uint256)) public withdrawApproval;

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (Kernel.Keycode) {
        return Kernel.Keycode.wrap("TRSRY");
    }

    function ROLES() public pure override returns (Kernel.Role[] memory roles) {
        roles = new Kernel.Role[](1);
        roles[0] = APPROVER;
    }

    // Must be carefully managed by governance.
    function requestApprovalFor(
        address withdrawer_,
        ERC20 token_,
        uint256 amount_
    ) external onlyRole(APPROVER) {
        withdrawApproval[withdrawer_][token_] = amount_;

        emit ApprovedForWithdrawal(withdrawer_, token_, amount_);
    }

    function withdrawReserves(
        address to_,
        ERC20 token_,
        uint256 amount_
    ) external {
        uint256 approval = withdrawApproval[msg.sender][token_];
        if (approval < amount_) revert TRSRY_NotApproved();

        // Check for infinite approval
        if (approval != type(uint256).max)
            withdrawApproval[msg.sender][token_] = approval - amount_;

        token_.safeTransfer(to_, amount_);

        emit Withdrawal(msg.sender, to_, token_, amount_);
    }

    // Anyone can call to revoke a terminated policy's approvals
    function revokeApprovals(address withdrawer_, ERC20[] memory tokens_)
        external
    {
        if (kernel.approvedPolicies(msg.sender) == true)
            revert TRSRY_PolicyStillActive();

        uint256 len = tokens_.length;
        for (uint256 i; i < len; ) {
            withdrawApproval[withdrawer_][tokens_[i]] = 0;
            unchecked {
                ++i;
            }
        }

        emit ApprovalRevoked(withdrawer_, tokens_);
    }
}
