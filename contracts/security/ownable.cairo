%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero


//
// Storage
//

@storage_var
func Ownable_owner() -> (owner: felt) {
}

namespace Ownable {
    //
    // Initializer
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
        _transfer_ownership(owner);
        return ();
    }

    //
    // Guards
    //

    func assert_only_VME{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        let (owner) = Ownable.owner();
        let (caller) = get_caller_address();
        with_attr error_message("Ownable: caller is the zero address") {
            assert_not_zero(caller);
        }
        with_attr error_message("Ownable: caller is not the owner") {
            assert owner = caller;
        }
        return ();
    }

    //
    // Public
    //

    func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
        return Ownable_owner.read();
    }

    func transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_owner: felt
    ) {
        with_attr error_message("Ownable: new owner is the zero address") {
            assert_not_zero(new_owner);
        }
        assert_only_VME();
        _transfer_ownership(new_owner);
        return ();
    }

    func renounce_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
        assert_only_VME();
        _transfer_ownership(0);
        return ();
    }

    //
    // Internal
    //

    func _transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_owner: felt
    ) {
        let (previous_owner: felt) = Ownable.owner();
        Ownable_owner.write(new_owner);
        return ();
    }
}