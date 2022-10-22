%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.options.library import SmartAccount, Options, Values


//
/// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        optio_address: felt, erc20_address: felt, pool_address: felt, vault_address: felt, class_id: felt
    ) {
    Options.initialize(optio_address, erc20_address, pool_address, vault_address, class_id);
    return ();
}

//
// External functions
//

@external
func makeDeposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        amount: felt
    ) {
    Options.make_deposit(amount);
    return ();
}

@external
func makeWithdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        amount: felt
    ) {
    Options.make_withdraw(amount);
    return ();
}

@external
func tradeOption{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt,
        strike: felt,
        amount: felt,
        expiration: felt,
        exponentiation: felt,
        option_writer: SmartAccount,
        option_buyer: SmartAccount,
        collateral: felt,
        premium: felt,
        metadata_ids_len: felt,
        metadata_ids: felt*,
        values_len: felt,
        values: Values*,
    ) {
    Options.trade_option(
        class_id,
        strike,
        amount,
        expiration,
        exponentiation,
        option_writer,
        option_buyer,
        collateral,
        premium,
        metadata_ids_len,
        metadata_ids,
        values_len,
        values,
    );
    return ();
}

@external
func createOffer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, strike: felt, amount: felt, expiration: felt,
    ) {
    Options.create_offer(class_id, strike, amount, expiration);
    return ();
}

@external
func cancelOffer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, unit_id: felt, nonce: felt, amount: felt
    ) {
    Options.cancel_offer(class_id, unit_id, nonce, amount);
    return ();
}

@external
func writeOption{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        nonce: felt,
        class_id: felt,
        writer_address: felt,
        buyer_address: felt,
        premium: felt,
        metadata_ids_len: felt,
        metadata_ids: felt*,
        values_len: felt,
        values: Values*,
    ) {
    Options.write_option(
        nonce,
        class_id,
        writer_address,
        buyer_address,
        premium,
        metadata_ids_len,
        metadata_ids,
        values_len,
        values,
    );
    return ();
}

@external
func redeemOption{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, unit_id: felt, nonce: felt
    ) {
    Options.redeem_option(class_id, unit_id, nonce);
    return ();
}

@external
func exerciseOption{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_id: felt, unit_id: felt, nonce: felt, amount: felt
    ) {
    Options.exercise_option(class_id, unit_id, nonce, amount);
    return ();
}
