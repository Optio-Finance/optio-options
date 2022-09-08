%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

@storage_var
func ReentrancyGuard_entered(nonce: felt) -> (res: felt) {
}

namespace ReentrancyGuard {
    func start{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        nonce: felt
    ) {
        let (has_entered) = ReentrancyGuard_entered.read(nonce);
        with_attr error_message("ReentrancyGuard: reentrant call") {
            assert has_entered = FALSE;
        }
        ReentrancyGuard_entered.write(nonce, TRUE);
        return ();
    }

    func finish{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        nonce: felt
    ) {
        ReentrancyGuard_entered.write(nonce, FALSE);
        return ();
    }
}
