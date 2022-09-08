%lang starknet

from contracts.standard.library import Transaction, ClassMetadata, UnitMetadata, Values

// @title Interface for managing tokenized rights and obligations

@contract_interface
namespace IOptio {
    // @notice Allows transferring units in batches or individually
    // @param _from The address of the tokens holder
    // @param _to The address of the tokens recipient
    // @param _transactions_len The counter used for recursion
    // @param _transactions The set of transactions to be processed
    func transferFrom(
        _from: felt, _to: felt, _transactions_len: felt, _transactions: Transaction*
    ) {
    }

    // @notice Allows to transfer allowances in batches or individually
    // @param _from The address of the tokens holder
    // @param _to The address of the tokens recipient
    // @param _transactions_len The counter used for recursion
    // @param _transactions The set of transactions to be processed
    func transferAllowanceFrom(
        _from: felt, _to: felt, _transactions_len: felt, _transactions: Transaction*
    ) {
    }

    // @notice Allows issuing rights and obligations to an address
    // @dev Restricted to the authorized issuers of a contract
    // @param _to The address of the tokens recipient
    // @param _transactions_len The counter used for recursion
    // @param _transactions The set of transactions to be processed
    func issue(_to: felt, _transactions_len: felt, _transactions: Transaction*) {
    }

    // @notice Allows redeeming rights and obligations from an address
    // @dev Restricted to the authorized issuers of a contract
    // @param _to The address of the tokens recipient
    // @param _transactions_len The counter used for recursion
    // @param _transactions The set of transactions to be processed
    func redeem(_from: felt, _transactions_len: felt, _transactions: Transaction*) {
    }

    // @notice Allows burning tokens at the end of the token lifecycle
    // @param _from The address of the tokens holder
    // @param _transactions_len The counter used for recursion
    // @param _transactions The set of transactions to be processed
    func burn(_from: felt, _transactions_len: felt, _transactions: Transaction*) {
    }

    // @notice Allows `spender` to withdraw tokens from `owner` up to the approved limit
    func approve(owner: felt, spender: felt, transactions_len: felt, transactions: Transaction*) {
    }

    // @notice Allows to set or revoke `operator` approval to manage a caller's tokens
    func setApprovalFor(operator: felt, approved: felt) {
    }

    // @notice Returns the quantity of minted tokens for a certain Unit
    // @param class_id The unique ID of a particular Class
    // @param unit_id The unique ID of a particular Unit
    func totalSupply(class_id: felt, unit_id: felt) -> (balance: felt) {
    }

    // @notice Return the `caller` current balance for a certain Unit
    // @param class_id The unique ID of a particular Class
    // @param unit_id The unique ID of a particular Unit
    func balanceOf(account: felt, class_id: felt, unit_id: felt) -> (balance: felt) {
    }

    // @notice Returns the metamodel of a certain Class
    // @param class_id The unique ID of a particular Class
    // @param metadata_id The unique ID of a particular trait of the given Class
    func getClassMetadata(class_id: felt, metadata_id: felt) -> (classMetadata: ClassMetadata) {
    }

    // @notice Returns the metamodel of a certain Unit
    // @param class_id The unique ID of a particular Class
    // @param unit_id The unique ID of a particular Unit
    // @param metadata_id The unique ID of a particular trait of the given Unit
    func getUnitMetadata(class_id: felt, unit_id: felt, metadata_id: felt) -> (
        unitMetadata: UnitMetadata
    ) {
    }

    // @notice Returns the actual data of a certain Class
    // @param class_id The unique ID of a particular Class
    // @param metadata_id The unique ID of a particular trait of the given Class
    func getClassData(class_id: felt, metadata_id: felt) -> (classData: Values) {
    }

    // @notice Returns the actual data of a certain Unit
    // @param unit_id The unique ID of a particular Unit
    // @param metadata_id The unique ID of a particular trait of the given Unit
    func getUnitData(class_id: felt, unit_id: felt, metadata_id: felt) -> (unitData: Values) {
    }

    // @notice Returns the current progress of a Unit execution
    // @param class_id The unique ID of a particular Class
    // @param unit_id The unique ID of a particular Unit
    func getProgress(class_id: felt, unit_id: felt) -> (progress: felt) {
    }

    // @notice Returns the remaining amount of tokens `spender` is allowed to spend
    // @param owner The address which is allowing `spender` to spend some amount of `owner` tokens
    // @param spender The address which is going to be allowed for spending tokens
    // @param class_id The unique ID of a particular Class
    // @param unit_id The unique ID of a particular Unit
    func allowance(owner: felt, spender: felt, class_id: felt, unit_id: felt) -> (remaining: felt) {
    }

    // @notice Returns the approval status of the `operator` for a certain `owner`
    // @param owner The address which is approving `spender` to operate over all tokens in all `owner` Units
    // @param operator The address which is going to be approved for operating over tokens
    func isApprovedFor(owner: felt, operator: felt) -> (approved: felt) {
    }
}
