%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.options.library import Options


//
/// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        optio_address: felt, class_id: felt, pool_address: felt,
    ) {
    Options.initialize(optio_addres, class_id, pool_address);
    return ();
}

//
// External functions
//

@external
func createOffer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        strike: felt, amount: felt, expiration: felt,
    ) {
    Options.create_offer(strike, amount, expiration);
    return ();
}

@external
func cancelOffer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        nonce: felt
    ) {
    Options.create_offer(nonce);
    return ();
}