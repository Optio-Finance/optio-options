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


namespace Options {
    //
    /// Constructor
    //
    func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            optio_address: felt, class_id: felt, pool_address: felt,
        ) {
        optio_address.write(optio_address);
        pool_address.write(pool_address);
        class.write(class_id);
        return ();
    }

    //
    // Asks (offers)
    //

    func create_offer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        strike: felt, amount: felt, expiration: felt,
    ) {
        alloc_locals;

        let (nonce: felt) = create_nonce();
        let (current_timestamp: felt) = get_block_timestamp();

        with_attr error_message("create_offer: details could not be zeros") {
            assert_not_zero(strike);
            assert_not_zero(amount);
            assert_not_zero(expiration);
        }

        let (caller_address: felt) = get_caller_address();
        let (optio_address: felt) = optio_address.read();

        let (collateral_put: felt) = IOptio.transferFrom(
            contract_address=optio_address,
            _from=caller_address,
            to=pool_address,
        );

        with_attr error_message("create_offer: details could not be zeros") {
            collateral_put = TRUE;
        }

        let offer = Offer(
            nonce=nonce,
            strike=strike,
            amount=amount,
            expiration=expiration,
            writer_address=caller_address,
            is_matched=FALSE,
            is_active=TRUE,
        );
        offers.write(nonce, offer);

        return ();
    }

    func cancel_offer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            nonce: felt
        ) {
        alloc_locals;

        let (offer: Offer) = offers.read(nonce);
        let (pool_address: felt) = pool_address.read(nonce);
        let (caller_address: felt) = get_caller_address();

        with_attr error_message("cancel_offer: only writer can cancel") {
            assert caller_address = offer.writer;
        }

        with_attr error_message("cancel_offer: offer is no longer active") {
            assert offer.is_active = TRUE;
        }

        ReentrancyGuard.start(nonce);

        let (optio_address: felt) = optio_address.read();
        let (refund_succeed: felt) = IOptio.transferFrom(
            contract_address=optio_address,
            _from=pool_address,
            to=caller_address,
        );

        if (refund_succeed == TRUE) {
            let offer = Offer(
                nonce=nonce,
                strike=offer.strike,
                amount=offer.amount,
                expiration=offer.expiration,
                writer_address=offer.writer_address,
                is_matched=TRUE,
                is_active=FALSE,
            );
            offers.write(nonce, offer);
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }

        ReentrancyGuard.finish(nonce);

        with_attr error_message("cancel_offer: refund failed, state wasn't updated") {
            assert refund_succeed = TRUE;
        }

        return ();
    }
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