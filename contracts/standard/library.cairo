%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_not_zero, assert_not_equal, assert_le, assert_lt
from starkware.starknet.common.syscalls import (
    get_block_timestamp,
    get_caller_address,
    get_contract_address,
)


struct ClassProps {
    exists: felt,
    creator: felt,
    created: felt,
    latest_unit_id: felt,
    latest_unit_timestamp: felt,
    liquidity: felt,
    total_supply: felt,
}

struct ClassMetadata {
    class_id: felt,
    metadata_id: felt,
    name: felt,
    type: felt,
    description: felt,
}

struct UnitProps {
    unit_id: felt,
    exists: felt,
    creator: felt,
    created: felt,
    prev_unit_id: felt,
}

struct UnitMetadata {
    class_id: felt,
    unit_id: felt,
    metadata_id: felt,
    name: felt,
    type: felt,
    description: felt,
}

struct Values {
    uint: felt,
    string: felt,
    address: felt,
    boolean: felt,
    timestamp: felt,
    uri: felt,
}

struct Class {
    class_id: felt,
    name: felt,
    type: felt,
    description: felt,
    values: Values,
}

struct Unit {
    class_id: felt,
    unit_id: felt,
    class: felt,
    name: felt,
    type: felt,
    description: felt,
    values: Values,
}

struct Transaction {
    class_id: felt,
    unit_id: felt,
    amount: felt,
}


//
/// Storage
//

@storage_var
func classProps(class_id: felt) -> (props: ClassProps) {
}

@storage_var
func classMetadata(class_id: felt, metadata_id: felt) -> (classMetadata: ClassMetadata) {
}

@storage_var
func classes(class_id: felt, metadata_id: felt) -> (class: Values) {
}

@storage_var
func unitProps(class_id: felt, unit_id: felt) -> (props: UnitProps) {
}

@storage_var
func unitMetadata(class_id: felt, unit_id: felt, metadata_id: felt) -> (
    unitMetadata: UnitMetadata
) {
}

@storage_var
func units(class_id: felt, unit_id: felt, metadata_id: felt) -> (unit: Values) {
}

@storage_var
func operator_approvals(owner: felt, operator: felt) -> (approved: felt) {
}

@storage_var
func balances(address: felt, class_id: felt, unit_id: felt) -> (amount: felt) {
}

@storage_var
func allowances(address: felt, class_id: felt, unit_id: felt, spender: felt) -> (amount: felt) {
}

@storage_var
func name() -> (name: felt) {
}

@storage_var
func asset() -> (asset: felt) {
}

namespace OPTIO {
    //
    // Constructor
    //
    func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _name: felt, _asset: felt
    ) {
        name.write(_name);
        asset.write(_asset);
        return ();
    }

    func transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        sender: felt,
        recipient: felt,
        transaction_index: felt,
        transactions_len: felt,
        transactions: Transaction*,
    ) {
        if (transaction_index == transactions_len) {
            return ();
        }

        tempvar transaction = transactions[transaction_index];
        let (balance_sender) = balances.read(sender, transaction.class_id, transaction.unit_id);
        let (balance_recipient) = balances.read(
            recipient, transaction.class_id, transaction.unit_id
        );

        with_attr error_message(
                "_transfer_from: not enough funds to transfer, got sender's balance {balance_sender}") {
            assert_le(balance_sender, transaction.amount);
        }

        // @dev subtracting from a sender and adding to a recipient
        balances.write(
            sender,
            transaction.class_id,
            transaction.unit_id,
            balance_sender - transaction.amount
        );
        balances.write(
            recipient,
            transaction.class_id,
            transaction.unit_id,
            balance_recipient + transaction.amount,
        );

        transfer_from(
            sender=sender,
            recipient=recipient,
            transaction_index=transaction_index + 1,
            transactions_len=transactions_len,
            transactions=transactions,
        );
        return ();
    }

    func transfer_allowance_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt,
        sender: felt,
        recipient: felt,
        transaction_index: felt,
        transactions_len: felt,
        transactions: Transaction*,
    ) {
        if (transaction_index == transactions_len) {
            return ();
        }

        tempvar transaction = transactions[transaction_index];
        let (balance_sender) = balances.read(sender, transaction.class_id, transaction.unit_id);
        let (balance_recipient) = balances.read(
            recipient, transaction.class_id, transaction.unit_id
        );

        with_attr error_message(
                "_transfer_allowance_from: not enough funds to transfer, got sender's balance {balance_sender}") {
            assert_le(balance_sender, transaction.amount);
        }

        // reducing the caller's allowance and reflecting changes
        allowances.write(
            balance_sender,
            transaction.class_id,
            transaction.unit_id,
            recipient,
            balance_sender - transaction.amount,
        );
        balances.write(
            sender, transaction.class_id, transaction.unit_id, balance_sender - transaction.amount
        );
        balances.write(
            recipient,
            transaction.class_id,
            transaction.unit_id,
            balance_recipient + transaction.amount,
        );

        transfer_allowance_from(
            caller=caller,
            sender=sender,
            recipient=recipient,
            transaction_index=transaction_index + 1,
            transactions_len=transactions_len,
            transactions=transactions,
        );
        return ();
    }

    func issue{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        recipient: felt, transaction_index: felt, transactions_len: felt, transactions: Transaction*
    ) {
        if (transaction_index == transactions_len) {
            return ();
        }

        tempvar transaction = transactions[transaction_index];
        let (balance_recipient) = balances.read(
            recipient, transaction.class_id, transaction.unit_id
        );
        balances.write(
            recipient,
            transaction.class_id,
            transaction.unit_id,
            balance_recipient + transaction.amount,
        );

        issue(
            recipient=recipient,
            transaction_index=transaction_index + 1,
            transactions_len=transactions_len,
            transactions=transactions,
        );
        return ();
    }

    func redeem{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        sender: felt, transaction_index: felt, transactions_len: felt, transactions: Transaction*
    ) {
        if (transaction_index == transactions_len) {
            return ();
        }

        tempvar transaction = transactions[transaction_index];
        let (balance_sender) = balances.read(sender, transaction.class_id, transaction.unit_id);

        with_attr error_message(
                "_redeem: not enough funds to redeem, got sender's balance {balance_sender}") {
            assert_le(balance_sender, transaction.amount);
        }
        balances.write(
            sender, transaction.class_id, transaction.unit_id, balance_sender - transaction.amount
        );

        redeem(
            sender=sender,
            transaction_index=transaction_index + 1,
            transactions_len=transactions_len,
            transactions=transactions,
        );
        return ();
    }

    func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        sender: felt, transaction_index: felt, transactions_len: felt, transactions: Transaction*
    ) {
        if (transaction_index == transactions_len) {
            return ();
        }

        tempvar transaction = transactions[transaction_index];
        let (balance_sender) = balances.read(sender, transaction.class_id, transaction.unit_id);

        with_attr error_message("_burn: not enough funds, got sender's balance {balance_sender}") {
            assert_le(balance_sender, transaction.amount);
        }
        balances.write(
            sender, transaction.class_id, transaction.unit_id, balance_sender - transaction.amount
        );

        burn(
            sender=sender,
            transaction_index=transaction_index + 1,
            transactions_len=transactions_len,
            transactions=transactions,
        );
        return ();
    }

    func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt,
        spender: felt,
        transaction_index: felt,
        transactions_len: felt,
        transactions: Transaction*,
    ) {
        if (transaction_index == transactions_len) {
            return ();
        }

        tempvar tx = transactions[transaction_index];
        allowances.write(owner, tx.class_id, tx.unit_id, spender, tx.amount);

        approve(
            owner=owner,
            spender=spender,
            transaction_index=transaction_index + 1,
            transactions_len=transactions_len,
            transactions=transactions,
        );
        return ();
    }

    func set_approval_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, operator: felt, approved: felt
    ) {
        operator_approvals.write(owner, operator, approved);
        return ();
    }

    func create_class_metadata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, metadata_id: felt, metadata: ClassMetadata
    ) {
        classMetadata.write(class_id, metadata_id, metadata);
        return ();
    }

    func create_class_metadata_batch{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(
        index: felt,
        class_ids_len: felt,
        class_ids: felt*,
        metadata_ids_len: felt,
        metadata_ids: felt*,
        metadata_array_len: felt,
        metadata_array: ClassMetadata*,
    ) {
        if (index == metadata_array_len) {
            return ();
        }

        with_attr error_message("create_class_metadata_batch: inputs lengths not equal") {
            assert class_ids_len = metadata_ids_len;
            assert metadata_ids_len = metadata_array_len;
        }

        tempvar class_id = class_ids[index];
        tempvar metadata_id = metadata_ids[index];
        tempvar metadata = metadata_array[index];
        classMetadata.write(class_id, metadata_id, metadata);

        create_class_metadata_batch(
            index=index + 1,
            class_ids_len=class_ids_len,
            class_ids=class_ids,
            metadata_ids_len=metadata_ids_len,
            metadata_ids=metadata_ids,
            metadata_array_len=metadata_array_len,
            metadata_array=metadata_array,
        );
        return ();
    }

    func create_unit_metadata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, unit_id: felt, metadata_id: felt, metadata: UnitMetadata
    ) {
        unitMetadata.write(class_id, unit_id, metadata_id, metadata);
        return ();
    }

    func create_unit_metadata_batch{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(
        index: felt,
        class_ids_len: felt,
        class_ids: felt*,
        unit_ids_len: felt,
        unit_ids: felt*,
        metadata_ids_len: felt,
        metadata_ids: felt*,
        metadata_array_len: felt,
        metadata_array: UnitMetadata*,
    ) {
        if (index == metadata_array_len) {
            return ();
        }

        with_attr error_message("create_unit_metadata_batch: inputs lengths not equal") {
            assert class_ids_len = unit_ids_len;
            assert unit_ids_len = metadata_ids_len;
            assert metadata_ids_len = metadata_array_len;
        }

        tempvar class_id = class_ids[index];
        tempvar unit_id = unit_ids[index];
        tempvar metadata_id = metadata_ids[index];
        tempvar metadata = metadata_array[index];
        unitMetadata.write(class_id, unit_id, metadata_id, metadata);

        create_unit_metadata_batch(
            index=index + 1,
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

    func create_class{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt,
        class_id: felt,
        metadata_ids_len: felt,
        metadata_ids: felt*,
        values_len: felt,
        values: Values*,
    ) {
        if (index == metadata_ids_len) {
            return ();
        }

        with_attr error_message("create_class: inputs lengths not equal") {
            assert metadata_ids_len = values_len;
        }

        tempvar metadata_id = metadata_ids[index];
        tempvar value = values[index];
        classes.write(class_id, metadata_id, value);

        create_class(
            index=index + 1,
            class_id=class_id,
            metadata_ids_len=metadata_ids_len,
            metadata_ids=metadata_ids,
            values_len=values_len,
            values=values,
        );
        return ();
    }

    func initialize_class{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, 
        ) -> () {
        let (class: ClassProps) = classProps.read(class_id);

        with_attr error_message("initialize_class: class already exists") {
            assert class.exists = FALSE;
        }

        let (caller: felt) = get_caller_address();
        let (timestamp: felt) = get_block_timestamp();
        let class = ClassProps(
            exists=TRUE,
            creator=caller,
            created=timestamp,
            latest_unit_id=FALSE,
            latest_unit_timestamp=FALSE,
            liquidity=FALSE,
            total_supply=FALSE,
        );
        classProps.write(class_id, class);

        return ();
    }

    func update_class_latest_unit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, latest_unit_id: felt, latest_unit_timestamp: felt
        ) {
        let (class: ClassProps) = classProps.read(class_id);
        let (timestamp: felt) = get_block_timestamp();
        let updated_class = ClassProps(
            exists=class.exists,
            creator=class.creator,
            created=class.created,
            latest_unit_id=latest_unit_id,
            latest_unit_timestamp=latest_unit_timestamp,
            liquidity=class.liquidity,
            total_supply=class.total_supply,
        );
        classProps.write(class_id, class);
        return ();
    }

    func update_class_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, liquidity: felt
        ) {
        let (class: ClassProps) = classProps.read(class_id);
        let updated_class = ClassProps(
            exists=class.exists,
            creator=class.creator,
            created=class.created,
            latest_unit_id=class.latest_unit_id,
            latest_unit_timestamp=class.latest_unit_timestamp,
            liquidity=liquidity,
            total_supply=class.total_supply,
        );
        classProps.write(class_id, class);
        return ();
    }

    func update_class_total_supply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, total_supply: felt
        ) {
        let (class: ClassProps) = classProps.read(class_id);
        let updated_class = ClassProps(
            exists=class.exists,
            creator=class.creator,
            created=class.created,
            latest_unit_id=class.latest_unit_id,
            latest_unit_timestamp=class.latest_unit_timestamp,
            liquidity=class.liquidity,
            total_supply=total_supply,
        );
        classProps.write(class_id, class);
        return ();
    }

    func create_unit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt,
        class_id: felt,
        unit_id: felt,
        metadata_ids_len: felt,
        metadata_ids: felt*,
        values_len: felt,
        values: Values*,
    ) {
        if (index == metadata_ids_len) {
            return ();
        }

        with_attr error_message("create_unit: inputs lengths not equal") {
            assert metadata_ids_len = values_len;
        }

        tempvar metadata_id = metadata_ids[index];
        tempvar value = values[index];
        units.write(class_id, unit_id, metadata_id, value);

        create_unit(
            index=index + 1,
            class_id=class_id,
            unit_id=unit_id,
            metadata_ids_len=metadata_ids_len,
            metadata_ids=metadata_ids,
            values_len=values_len,
            values=values,
        );
        return ();
    }

    func initialize_unit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, unit_id: felt
        ) -> () {
        let (unit: UnitProps) = unitProps.read(class_id, unit_id);

        with_attr error_message("initialize_unit: unit already exists") {
            assert unit.exists = FALSE;
        }

        let (caller: felt) = get_caller_address();
        let (timestamp: felt) = get_block_timestamp();
        let unit = UnitProps(
            unit_id=unit_id,
            exists=TRUE,
            creator=caller,
            created=timestamp,
            prev_unit_id=FALSE,
        );
        unitProps.write(class_id, unit_id, unit);

        return ();
    }

    func update_unit_prev_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, unit_id: felt, prev_unit_id: felt
        ) {
        let (unit: UnitProps) = unitProps.read(class_id, unit_id);
        let updated_unit = UnitProps(
            unit_id=unit.unit_id,
            exists=unit.exists,
            creator=unit.creator,
            created=unit.created,
            prev_unit_id=prev_unit_id,
        );
        return ();
    }

    func balance_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt, class_id: felt, unit_id: felt
    ) -> (balance: felt) {
        // TODO class and unit checks
        let (balance) = balances.read(account, class_id, unit_id);
        return (balance,);
    }

    func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, spender: felt, class_id: felt, unit_id: felt
    ) -> (remaining: felt) {
        // TODO class and unit checks
        let (remaining) = allowances.read(owner, class_id, unit_id, spender);
        return (remaining,);
    }

    func get_class_metadata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, metadata_id: felt
    ) -> (classMetadata: ClassMetadata) {
        let (res) = classMetadata.read(class_id, metadata_id);
        return (classMetadata=res);
    }

    func get_unit_metadata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, unit_id: felt, metadata_id: felt
    ) -> (unitMetadata: UnitMetadata) {
        let (res) = unitMetadata.read(class_id, unit_id, metadata_id);
        return (unitMetadata=res);
    }

    func get_class_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, metadata_id: felt
    ) -> (classData: Values) {
        let (classData: Values) = classes.read(class_id, metadata_id);
        return (classData,);
    }

    func get_unit_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, unit_id: felt, metadata_id: felt
    ) -> (unitData: Values) {
        let (unitData: Values) = units.read(class_id, unit_id, metadata_id);
        return (unitData,);
    }

    func total_supply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller: felt, class_id: felt, unit_id: felt
    ) -> (balance: felt) {
        let (balance) = balances.read(caller, class_id, unit_id);
        return (balance,);
    }

    func get_progress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, unit_id: felt
    ) -> (progress: felt) {
        let (progress) = get_block_timestamp();
        return (progress,);
    }

    func is_approved_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, operator: felt
    ) -> (approved: felt) {
        let (approved) = operator_approvals.read(owner, operator);
        return (approved,);
    }

    func get_class_props{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt
        ) -> (class: ClassProps) {
        let (class: ClassProps) = classProps.read(class_id);
        with_attr error_message("get_class_props: class doesn't exist") {
            assert class.exists = TRUE;
        }
        return (class,);
    }

    func get_unit_props{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, unit_id: felt
        ) -> (unit: UnitProps) {
        let (unit: UnitProps) = unitProps.read(class_id, unit_id);
        with_attr error_message("get_unit_props: class doesn't exist") {
            assert unit.exists = TRUE;
        }
        return (unit,);
    }

    func get_latest_unit_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt
        ) -> (latest_unit_id: felt) {
        let (class: ClassProps) = classProps.read(class_id);
        with_attr error_message("get_latest_unit: class doesn't exist") {
            assert class.exists = TRUE;
        }
        let id = class.latest_unit_id;
        return (latest_unit_id=id);
    }

    func class_exists{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt
        ) -> (exists: felt) {
        let (class: ClassProps) = classProps.read(class_id);
        return (exists=class.exists);
    }

    func unit_exists{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, unit_id: felt
        ) -> (exists: felt) {
        let (unit: UnitProps) = unitProps.read(class_id, unit_id);
        return (exists=unit.exists);
    }

    func get_class_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt
        ) -> (liquidity: felt) {
        let (class: ClassProps) = classProps.read(class_id);
        with_attr error_message("get_class_liquidity: class doesn't exist") {
            assert class.exists = TRUE;
        }
        let liquidity = class.liquidity;
        return (liquidity=liquidity);
    }

    func get_class_total_supply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt
        ) -> (total_supply: felt) {
        let (class: ClassProps) = classProps.read(class_id);
        with_attr error_message("get_class_total_supply: class doesn't exist") {
            assert class.exists = TRUE;
        }
        let total_supply = class.total_supply;
        return (total_supply=total_supply);
    }
}
