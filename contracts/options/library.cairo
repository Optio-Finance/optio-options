%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_not_zero, assert_not_equal, assert_le, assert_lt
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address
)

from contracts.security.reentrancy_guard import ReentrancyGuard

// @notice Offer data goes into Matching Engine
// @dev No obligations at this stage
// @param nonce Unique ID assigned for full lifecycle
// @param strike Option strike price
// @param expiration Option expiry in seconds (e.g. 86,400)
// @param amount Size of the offered position
// @param writer_address The address of the option seller
struct Offer {
    nonce: felt,
    strike: felt,
    amount: felt,
    expiration: felt,
    writer_address: felt,
    is_matched: felt,
    is_active: felt,
}

// @notice Options are being created after matching
// @dev Transfers should be decorated by ReentrancyGuard
// @dev Main params are equal to the relevant offer
// @dev premium The premium (fee) taken from a buyer
struct Option {
    class_id: felt,
    unit_id: felt,
    nonce: felt,
    strike: felt,
    amount: felt,
    expiration: felt,
    premium: felt,
    writer_address: felt,
    buyer_address: felt,
    is_active: felt,
}

@storage_var
func optio_address() -> (optio_address: felt) {
}

@storage_var
func pool_address() -> (pool_address: felt) {
}

@storage_var
func class() -> (class_id: felt) {
}

@storage_var
func nonce() -> (nonce: felt) {
}

@storage_var
func offers(nonce: felt) -> (offer: Offer) {
}

@storage_var
func options(nonce: felt) -> (option: Option) {
}

// Helpers

func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (nonce: felt) {
    let (nonce: felt) = nonce.read();
    return (nonce);
}

func update_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(nonce: felt) -> () {
    nonce.write(nonce);
    return ();
}

func create_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (nonce: felt) {
    let (nonce: felt) = get_nonce();
    tempvar nonce_id = nonce + 1;
    update_nonce(nonce_id);
    return (nonce_id);
}