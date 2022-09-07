%lang starknet

from src.account.Account import AccountCallArray

@contract_interface
namespace IAccount {
    func get_nonce() -> (res: felt) {
    }

    func is_valid_signature(hash: felt, signature_len: felt, signature: felt*) {
    }

    func __execute__(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        nonce: felt,
    ) -> (response_len: felt, response: felt*) {
    }
}
