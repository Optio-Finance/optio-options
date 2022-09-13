%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal, assert_le
from starkware.starknet.common.syscalls import (
    get_block_timestamp,
    get_caller_address,
    get_contract_address,
)
from contracts.standard.library import (
    ClassMetadata, UnitMetadata,
    ClassProps, UnitProps,
    Class, Unit,
    Values, Transaction,
)

from contracts.security.reentrancy_guard import ReentrancyGuard
from contracts.standard.library import OPTIO

//
/// Events
//

@event
func Transfer(caller: felt, sender: felt, recipient: felt, transactions_len: felt, transactions: felt*) {
}

@event
func Issue(caller: felt, recipient: felt, transactions_len: felt, transactions: felt*) {
}

@event
func Redeem(caller: felt, sender: felt, transactions_len: felt, transactions: felt*) {
}

@event
func Burn(caller: felt, sender: felt, transactions_len: felt, transactions: felt*) {
}

@event
func ApprovalFor(caller: felt, operator: felt, approved: felt) {
}

//
/// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt, asset: felt
) {
    OPTIO.initialize(name, asset);
    return ();
}

//
/// Externals
//

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, transactions_len: felt, transactions: Transaction*
) {
    alloc_locals;
    with_attr error_message("transferFrom: can't transfer from zero address, got sender={sender}") {
        assert_not_zero(sender);
    }

    with_attr error_message("transferFrom: use burn() instead, got recipient={recipient}") {
        assert_not_zero(recipient);
    }

    let (local caller) = get_caller_address();
    OPTIO.transfer_from(
        sender=sender,
        recipient=recipient,
        transaction_index=0,
        transactions_len=transactions_len,
        transactions=transactions,
    );
    Transfer.emit(caller, sender, recipient, transactions_len, transactions);

    return ();
}

@external
func transferAllowanceFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, transactions_len: felt, transactions: Transaction*
) {
    alloc_locals;
    with_attr error_message(
            "transferAllowanceFrom: can't transfer allowance from zero address, got sender={sender}") {
        assert_not_zero(sender);
    }

    with_attr error_message("transferAllowanceFrom: use burn() instead, got recipient={recipient}") {
        assert_not_zero(recipient);
    }

    let (local caller) = get_caller_address();
    OPTIO.transfer_allowance_from(
        caller=caller,
        sender=sender,
        recipient=recipient,
        transaction_index=0,
        transactions_len=transactions_len,
        transactions=transactions,
    );
    Transfer.emit(caller, sender, recipient, transactions_len, transactions);

    return ();
}

@external
func issue{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, transactions_len: felt, transactions: Transaction*
) {
    alloc_locals;
    with_attr error_message("issue: can't issue to zero address, got recipient={recipient}") {
        assert_not_zero(recipient);
    }

    OPTIO.issue(
        recipient=recipient,
        transaction_index=0,
        transactions_len=transactions_len,
        transactions=transactions,
    );
    let (caller) = get_caller_address();
    Issue.emit(caller, recipient, transactions_len, transactions);

    return ();
}

@external
func redeem{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, transactions_len: felt, transactions: Transaction*
) {
    alloc_locals;
    with_attr error_message("redeem: can't redeem from zero address, got sender={sender}") {
        assert_not_zero(sender);
    }

    OPTIO.redeem(
        sender=sender,
        transaction_index=0,
        transactions_len=transactions_len,
        transactions=transactions,
    );
    let (caller) = get_caller_address();
    Redeem.emit(caller, sender, transactions_len, transactions);

    return ();
}

@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, transactions_len: felt, transactions: Transaction*
) {
    alloc_locals;
    let (local caller) = get_caller_address();
    with_attr error_message("burn: caller is not owner, got sender={sender}") {
        assert caller = sender;
    }

    OPTIO.burn(
        sender=sender,
        transaction_index=0,
        transactions_len=transactions_len,
        transactions=transactions,
    );
    Burn.emit(caller, sender, transactions_len, transactions);

    return ();
}

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt, transactions_len: felt, transactions: Transaction*
) {
    alloc_locals;
    with_attr error_message("approve: zero address, got owner={owner}, spender={spender}") {
        assert_not_zero(owner);
        assert_not_zero(spender);
    }

    let (local caller) = get_caller_address();
    with_attr error_message("approve: can't approve own, got owner={owner}, spender={spender}") {
        assert_not_equal(owner, spender);
        assert_not_equal(caller, spender);
    }

    OPTIO.approve(
        owner=owner,
        spender=spender,
        transaction_index=0,
        transactions_len=transactions_len,
        transactions=transactions,
    );
    return ();
}

@external
func setApprovalFor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    operator: felt, approved: felt
) {
    alloc_locals;
    let (local owner) = get_caller_address();
    with_attr error_message("setApprovalFor: zero address, got operator={operator}") {
        assert_not_zero(operator);
    }

    OPTIO.set_approval_for(owner, operator, approved);
    ApprovalFor.emit(owner, operator, approved);
    return ();
}

@external
func createClassMetadata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, metadata_id: felt, metadata: ClassMetadata
) {
    OPTIO.create_class_metadata(class_id, metadata_id, metadata);
    return ();
}

@external
func createClassMetadataBatch{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_ids_len: felt,
    class_ids: felt*,
    metadata_ids_len: felt,
    metadata_ids: felt*,
    metadata_array_len: felt,
    metadata_array: ClassMetadata*,
) {
    with_attr error_message("createClassMetadataBatch: got zero inputs lengths") {
        assert_not_zero(class_ids_len);
        assert_not_zero(metadata_ids_len);
    }
    OPTIO.create_class_metadata_batch(
        index=0,
        class_ids_len=class_ids_len,
        class_ids=class_ids,
        metadata_ids_len=metadata_ids_len,
        metadata_ids=metadata_ids,
        metadata_array_len=metadata_array_len,
        metadata_array=metadata_array,
    );
    return ();
}

@external
func createUnitMetadata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, unit_id: felt, metadata_id: felt, metadata: UnitMetadata
) {
    OPTIO.create_unit_metadata(class_id, unit_id, metadata_id, metadata);
    return ();
}

@external
func createUnitMetadataBatch{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_ids_len: felt,
    class_ids: felt*,
    unit_ids_len: felt,
    unit_ids: felt*,
    metadata_ids_len: felt,
    metadata_ids: felt*,
    metadata_array_len: felt,
    metadata_array: UnitMetadata*,
) {
    with_attr error_message("createClassMetadataBatch: got zero inputs lengths") {
        assert_not_zero(class_ids_len);
        assert_not_zero(unit_ids_len);
        assert_not_zero(metadata_ids_len);
        assert_not_zero(metadata_array_len);
    }
    OPTIO.create_unit_metadata_batch(
        index=0,
        class_ids_len=class_ids_len,
        class_ids=class_ids,
        unit_ids_len=unit_ids_len,
        unit_ids=unit_ids,
        metadata_ids_len=metadata_ids_len,
        metadata_ids=metadata_ids,
        metadata_array_len=metadata_array_len,
        metadata_array=metadata_array,
    );
    return ();
}

@external
func createClass{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, metadata_ids_len: felt, metadata_ids: felt*, values_len: felt, values: Values*
) {
    with_attr error_message("createClass: got zero inputs lengths") {
        assert_not_zero(metadata_ids_len);
        assert_not_zero(values_len);
    }
    OPTIO.create_class(
        index=0,
        class_id=class_id,
        metadata_ids_len=metadata_ids_len,
        metadata_ids=metadata_ids,
        values_len=values_len,
        values=values,
    );
    OPTIO.initialize_class(class_id);
    return ();
}

@external
func createUnit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt,
    unit_id: felt,
    metadata_ids_len: felt,
    metadata_ids: felt*,
    values_len: felt,
    values: Values*,
) {
    with_attr error_message("createUnit: got zero inputs lengths") {
        assert_not_zero(metadata_ids_len);
        assert_not_zero(values_len);
    }
    OPTIO.create_unit(
        index=0,
        class_id=class_id,
        unit_id=unit_id,
        metadata_ids_len=metadata_ids_len,
        metadata_ids=metadata_ids,
        values_len=values_len,
        values=values,
    );
    return ();
}

@external
func updateClassLatestUnit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, latest_unit_id: felt, latest_unit_timestamp: felt
    ) {
    OPTIO.update_class_latest_unit(class_id, latest_unit_id, latest_unit_timestamp);
    return ();
}

//
//
/// Getters
//
//

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt, class_id: felt, unit_id: felt
) -> (balance: felt) {
    with_attr error_message("balanceOf: balance query for zero address") {
        assert_not_zero(account);
    }

    let (balance: felt) = OPTIO.balance_of(account=account, class_id=class_id, unit_id=unit_id);
    return (balance,);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt, class_id: felt, unit_id: felt
) -> (remaining: felt) {
    with_attr error_message("allowance: query for zero address") {
        assert_not_zero(owner);
        assert_not_zero(spender);
    }

    let (remaining: felt) = OPTIO.allowance(
        owner=owner, spender=spender, class_id=class_id, unit_id=unit_id
    );
    return (remaining,);
}

@view
func getClassMetadata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, metadata_id: felt
) -> (classMetadata: ClassMetadata) {
    // TODO check if classMetadata exists
    let (classMetadata: ClassMetadata) = OPTIO.get_class_metadata(class_id, metadata_id);
    return (classMetadata,);
}

@view
func getUnitMetadata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, unit_id: felt, metadata_id: felt
) -> (unitMetadata: UnitMetadata) {
    // TODO check if unitMetadata exists
    let (unitMetadata: UnitMetadata) = OPTIO.get_unit_metadata(class_id, unit_id, metadata_id);
    return (unitMetadata,);
}

@view
func getClassData{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, metadata_id: felt
) -> (classData: Values) {
    // TODO check if class exists
    let (classData: Values) = OPTIO.get_class_data(class_id, metadata_id);
    return (classData,);
}

@view
func getUnitData{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, unit_id: felt, metadata_id: felt
) -> (unitData: Values) {
    // TODO check if class and unit exist
    let (unitData: Values) = OPTIO.get_unit_data(class_id, unit_id, metadata_id);
    return (unitData,);
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, unit_id: felt
) -> (balance: felt) {
    alloc_locals;
    let (caller) = get_caller_address();

    let (balance) = OPTIO.total_supply(caller, class_id, unit_id);
    return (balance,);
}

@view
func getProgress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_id: felt, unit_id: felt
) -> (progress: felt) {
    let (progress) = OPTIO.get_progress(class_id, unit_id);
    return (progress,);
}

@view
func isApprovedFor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, operator: felt
) -> (approved: felt) {
    let (approved) = OPTIO.is_approved_for(owner, operator);
    return (approved,);
}

@view
func getLatestUnit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt
    ) -> (latest_unit_id: felt) {
    let (latest_unit_id) = OPTIO.get_latest_unit_id(class_id);
    return (latest_unit_id,);
}

@view
func getClassProps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt
    ) -> (class: ClassProps) {
    let (class: ClassProps) = OPTIO.get_class_props(class_id);
    return (class,);
}

@view
func getUnitProps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, unit_id: felt
    ) -> (unit: UnitProps) {
    let (unit: UnitProps) = OPTIO.get_unit_props(class_id, unit_id);
    return (unit,);
}