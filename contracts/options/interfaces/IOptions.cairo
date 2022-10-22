%lang starknet

// @title Interface for creating and managing offers and options contracts

@contract_interface
namespace IOptions {

    func makeDeposit(amount: felt) {
    }

    func makeWithdraw(amount: felt) {
    }

    // @notice Allows to create offers (asks) to be consumed by ME
    // @param strike The strike price for underlying asset
    // @param amount The size of the ask
    // @param expiration The expiry date of the option
    func createOffer(strike: felt, amount: felt, expiration: felt) {
    }

    // @notice Allows to cancel offers if not matched
    // @param nonce The unique ID of the ask
    func cancelOffer(nonce: felt) {
    }

    // @notice Allows to create the actial options contract after matching
    // @param nonce The unique ID of the ask which is inherited by the option contract
    // @param writer_address The address of the option's writer
    // @param buyer_address The address of the option's buyer
    func writeOption(nonce: felt, writer_address: felt, buyer_address: felt, fee: felt) {
    }

    // @notice Allows to redeem the option if expired but not exercised
    // @dev Writer only
    // @param nonce The unique ID of the option
    func redeemOption(nonce: felt) {
    }

    // @notice Allows to exercise the option
    // @dev Buyer only
    // @param nonce The unique ID of the option
    func exerciseOption(nonce: felt) {
    }
}