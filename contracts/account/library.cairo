%lang starknet

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import call_contract, get_caller_address, get_tx_info
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from contracts.introspection.ERC165 import ERC165_supports_interface, ERC165_register_interface

from contracts.utils.constants import IACCOUNT_ID

//
// Structs
//

struct Call {
    to: felt,
    selector: felt,
    calldata_len: felt,
    calldata: felt*,
}

struct AccountCallArray {
    to: felt,
    selector: felt,
    data_offset: felt,
    data_len: felt,
}

//
// Storage
//

@storage_var
func Account_current_nonce() -> (res: felt) {
}

@storage_var
func Account_public_key() -> (res: felt) {
}

//
// Guards
//

func Account_assert_only_self{syscall_ptr: felt*}() {
    let (self) = get_contract_address();
    let (caller) = get_caller_address();
    with_attr error_message("Account: caller is not this account") {
        assert self = caller;
    }
    return ();
}

//
// Getters
//

func Account_get_public_key{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let (res) = Account_public_key.read();
    return (res=res);
}

func Account_get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let (res) = Account_current_nonce.read();
    return (res=res);
}

//
// Setters
//

func Account_set_public_key{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_public_key: felt
) {
    Account_assert_only_self();
    Account_public_key.write(new_public_key);
    return ();
}

//
// Initializer
//

func Account_initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _public_key: felt
) {
    Account_public_key.write(_public_key);
    ERC165_register_interface(IACCOUNT_ID);
    return ();
}

func Account_is_valid_signature{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(hash: felt, signature_len: felt, signature: felt*) -> () {
    let (_public_key) = Account_public_key.read();

    let sig_r = signature[0];
    let sig_s = signature[1];

    verify_ecdsa_signature(
        message=hash, public_key=_public_key, signature_r=sig_r, signature_s=sig_s
    );

    return ();
}

func Account_execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(
    call_array_len: felt,
    call_array: AccountCallArray*,
    calldata_len: felt,
    calldata: felt*,
    nonce: felt,
) -> (response_len: felt, response: felt*) {
    alloc_locals;

    let (__fp__, _) = get_fp_and_pc();
    let (tx_info) = get_tx_info();
    let (_current_nonce) = Account_current_nonce.read();

    // validate nonce
    assert _current_nonce = nonce;

    // TMP: Convert `AccountCallArray` to 'Call'.
    let (calls: Call*) = alloc();
    from_call_array_to_call(call_array_len, call_array, calldata, calls);
    let calls_len = call_array_len;

    // validate transaction
    Account_is_valid_signature(tx_info.transaction_hash, tx_info.signature_len, tx_info.signature);

    // bump nonce
    Account_current_nonce.write(_current_nonce + 1);

    // execute call
    let (response: felt*) = alloc();
    let (response_len) = execute_list(calls_len, calls, response);

    return (response_len=response_len, response=response);
}

func execute_list{syscall_ptr: felt*}(calls_len: felt, calls: Call*, response: felt*) -> (
    response_len: felt
) {
    alloc_locals;

    // if no more calls
    if (calls_len == 0) {
        return (0,);
    }

    // do the current call
    let this_call: Call = [calls];
    let res = call_contract(
        contract_address=this_call.to,
        function_selector=this_call.selector,
        calldata_size=this_call.calldata_len,
        calldata=this_call.calldata,
    );
    // copy the result in response
    memcpy(response, res.retdata, res.retdata_size);
    // do the next calls recursively
    let (response_len) = execute_list(
        calls_len - 1, calls + Call.SIZE, response + res.retdata_size
    );
    return (response_len + res.retdata_size,);
}

func from_call_array_to_call{syscall_ptr: felt*}(
    call_array_len: felt, call_array: AccountCallArray*, calldata: felt*, calls: Call*
) {
    // if no more calls
    if (call_array_len == 0) {
        return ();
    }

    // parse the current call
    assert [calls] = Call(
        to=[call_array].to,
        selector=[call_array].selector,
        calldata_len=[call_array].data_len,
        calldata=calldata + [call_array].data_offset
        );

    // parse the remaining calls recursively
    from_call_array_to_call(
        call_array_len - 1, call_array + AccountCallArray.SIZE, calldata, calls + Call.SIZE
    );
    return ();
}
