%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.options.library import Options, Values


//
/// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        optio_address: felt, class_id: felt, pool_address: felt,
    ) {
    Options.initialize(optio_address, class_id, pool_address);
    return ();
}

//
// External functions
//

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
        nonce: felt, writer_address: felt, buyer_address: felt, fee: felt,
    ) {
    Options.write_option(nonce, writer_address, buyer_address);
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
