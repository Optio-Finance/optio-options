%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_le, uint256_check
from starkware.cairo.common.math import assert_not_zero, assert_lt, assert_le, unsigned_div_rem, split_felt
from starkware.cairo.common.pow import pow
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address
)

from contracts.token.IERC20 import IERC20
from contracts.security.reentrancy_guard import ReentrancyGuard
from contracts.security.ownable import Ownable
from contracts.standard.interfaces.IOptio import IOptio
from contracts.standard.library import Transaction, Values
from contracts.oracles.empiric import IEmpiricOracle, EMPIRIC_ORACLE_ADDRESS, PAIR, AGGREGATION_MODE


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
    exponentiation: felt,
    premium: felt,
    created: felt,
    writer_address: felt,
    buyer_address: felt,
    is_covered: felt,
    is_active: felt,
}

struct SmartAccount {
    wallet_address: felt,
    address: felt,
    available: felt,
    locked: felt,
    total_balance: felt,
}

struct Offer {
    class_id: felt,
    unit_id: felt,
    nonce: felt,
    strike: felt,
    amount: felt,
    expiration: felt,
    exponentiation: felt,
    created: felt,
    writer_address: felt,
    is_matched: felt,
    is_active: felt,
}

//
/// Events for ME callbacks
//

@event
func DepositMade(account: SmartAccount) {
}

@event
func DepositWithdrawn(account: SmartAccount) {
}

@event
func OfferCreated(offer: Offer) {
}

@event
func OfferCancelled(offer: Offer) {
}

@event
func OptionCreated(option: Option) {
}

@event
func OptionRedeemed(option: Option) {
}

@event
func OptionExercised(option: Option) {
}

//
/// Storage
//

@storage_var
func optio_standard() -> (optio_address: felt) {
}

@storage_var
func optio_pool() -> (pool_address: felt) {
}

@storage_var
func optio_vault() -> (vault_address: felt) {
}

@storage_var
func underlying() -> (erc20_address: felt) {
}

@storage_var
func accounts(address: felt) -> (account: SmartAccount) {
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
            optio_address: felt, pool_address: felt, class_id: felt, erc20_address: felt
        ) {
        optio_standard.write(optio_address);
        optio_pool.write(pool_address);
        underlying.write(erc20_address);
        class.write(class_id);
        return ();
    }

    func make_deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            amount: felt
        ) {
        with_attr error_message("make_deposit: got zero amount") {
            assert_not_zero(amount);
        }
        let (amount_uint256: Uint256) = felt_to_uint(amount);
        let (caller_address: felt) = get_caller_address();
        let (erc20_address: felt) = underlying.read();
        let (smart_account: SmartAccount) = accounts.read(caller_address);

        let (deposit_success: felt) = IERC20.transferFrom(
            contract_address=erc20_address,
            sender=caller_address,
            recipient=smart_account.address, // TODO smart accounts contract
            amount=amount_uint256,
        );

        with_attr error_message("make_deposit: deposit operation failed") {
            assert deposit_success = TRUE;
        }

        if (smart_account.address == FALSE) {
            accounts.write(caller_address, SmartAccount(
                address=caller_address,
                available=amount,
                locked=0,
                total_balance=amount,
            ));
        } else {
            accounts.write(caller_address, SmartAccount(
                address=caller_address,
                available=smart_account.available + amount,
                locked=smart_account.locked,
                total_balance=smart_account.total_balance + amount,
            ));
        }

        let (updated_account: SmartAccount) = accounts.read(caller_address);
        DepositMade(updated_account);
        
        return ();
    }

    func make_withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            amount: felt
        ) {
        let (caller_address: felt) = get_caller_address();
        let (erc20_address: felt) = underlying.read();
        let (smart_account: SmartAccount) = accounts.read(caller_address);

        with_attr error_message("make_deposit: zero inputs or smart_account={smart_account}") {
            assert_not_zero(amount);
            assert_not_zero(smart_account.address);
            assert_le(amount, smart_account.available);
            assert_le(amount, smart_account.total_balance);
        }

        let (withdrawal_success: felt) = IERC20.transferFrom(
            contract_address=erc20_address,
            sender=smart_account.address, // TODO smart accounts contract
            recipient=caller_address,
            amount=amount,
        );

        with_attr error_message("withdraw_deposit: transfer failed") {
            assert withdrawal_success = TRUE;
        }

        accounts.write(caller_address, SmartAccount(
            address=caller_address,
            available=smart_account.available - amount,
            locked=smart_account.locked,
            total_balance=smart_account.total_balance - amount,
        ));

        let (updated_account: SmartAccount) = accounts.read(caller_address);
        DepositWithdrawn(updated_account);

        return ();
    }

    //
    // Option instance methods
    //

    func trade_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt,
            strike: felt,
            amount: felt,
            expiration: felt,
            exponentiation: felt,
            option_writer: SmartAccount,
            option_buyer: SmartAccount,
            collateral: felt,
            premium: felt,
            metadata_ids_len: felt,
            metadata_ids: felt*,
            values_len: felt,
            values: Values*,
        ) {
        Ownable.assert_only_VME();

        with_attr error_message("create_offer: got zero inputs lengths") {
            assert_not_zero(metadata_ids_len);
            assert_not_zero(values_len);
        }

        let (nonce: felt) = create_nonce();
        let (optio_address: felt) = optio_standard.read();
        let (pool_address: felt) = optio_pool.read();
        let (vault_address: felt) = optio_vault.read();
        let (current_timestamp) = get_block_timestamp();

        ReentrancyGuard.start(nonce);

        let (prev_unit_id: felt) = IOptio.getLatestUnit(contract_address=optio_address, class_id=class_id);
        let unit_id = prev_unit_id + 1;

        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, collateral);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=option_writer.address,
            recipient=vault_address,
            transactions_len=1,
            transactions=transactions,
        );

        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, premium);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=option_buyer.address,
            recipient=option_writer.address,
            transactions_len=1,
            transactions=transactions,
        );

        // @dev Creating the actual option
        IOptio.createUnit(
            contract_address=optio_address,
            class_id=class_id,
            unit_id=unit_id,
            metadata_ids_len=metadata_ids_len,
            metadata_ids=metadata_ids,
            values_len=values_len,
            values=values
        );
        let option = Option(
            class_id=class_id,
            unit_id=unit_id,
            nonce=nonce,
            strike=strike,
            amount=amount,
            expiration=current_timestamp + expiration,
            exponentiation=exponentiation,
            premium=premium,
            created=current_timestamp,
            writer_address=option_writer.address,
            buyer_address=option_buyer.address,
            is_covered=TRUE,
            is_active=TRUE,
        );
        options.write(nonce, option);

        // @dev Minting LP tokens
        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, amount);
        IOptio.issue(
            contract_address=optio_address,
            recipient=option_buyer.address,
            transactions_len=1,
            transactions=transactions
        );

        // @dev Emitting events for ME
        OptionCreated.emit(option);

        ReentrancyGuard.finish(nonce);

        return ();
    }

    func exercise_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, unit_id: felt, nonce: felt, amount: felt
        ) {
        Ownable.assert_only_VME();

        let (optio_address: felt) = optio_standard.read();
        let (vault_address: felt) = optio_vault.read();
        let (option: Option) = options.read(nonce);
        let (current_timestamp) = get_block_timestamp();

        with_attr error_message("exercise_option: option is not active") {
            assert option.is_active = TRUE;
        }

        let (
            oracle_price,
            oracle_decimals,
            last_updated_timestamp, // UNIX format, in seconds since epoch
            num_sources_aggregated
        ) = IEmpiricOracle.get_value(EMPIRIC_ORACLE_ADDRESS, PAIR, AGGREGATION_MODE);

        with_attr error_message("exercise_option: out of time constraints") {
            assert_lt(current_timestamp, last_updated_timestamp + 300); // 5 min window
        }

        let (buyer_profit, writer_return) = calculate_profit(
            current_price=oracle_price,
            strike_price=option.strike,
            amount=amount,
            decimals=oracle_decimals,
        );

        ReentrancyGuard.start(nonce);

        // @notice Sending profits to the buyer
        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, buyer_profit);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=vault_address,
            recipient=option.buyer_address,
            transactions_len=1,
            transactions=transactions,
        );

        // @notice Sending remainder to the writer
        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, writer_return);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=vault_address,
            recipient=option.writer_address,
            transactions_len=1,
            transactions=transactions,
        );

        let option = Option(
            class_id=option.class_id,
            unit_id=option.unit_id,
            nonce=nonce,
            strike=option.strike,
            amount=option.amount,
            expiration=option.expiration,
            exponentiation=option.exponentiation,
            premium=option.premium,
            created=option.created,
            writer_address=option.writer_address,
            buyer_address=option.buyer_address,
            is_covered=option.is_covered,
            is_active=FALSE,
        );
        options.write(nonce, option);
        OptionExercised.emit(option);

        ReentrancyGuard.finish(nonce);

        return ();
    }

    // @notice In case if expired by not exercised
    func redeem_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, unit_id: felt, nonce: felt
        ) {
        Ownable.assert_only_VME();

        let (option: Option) = options.read(nonce);
        let (current_timestamp: felt) = get_block_timestamp();

        with_attr error_message("redeem_option: option has been set inactive") {
            assert option.is_active = TRUE;
        }
        with_attr error_message("redeem_option: option is not expired yet") {
            assert_lt(option.expiration, current_timestamp);
        }

        ReentrancyGuard.start(nonce);

        let (optio_address: felt) = optio_standard.read();
        let (pool_address: felt) = optio_pool.read();

        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, option.amount);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=pool_address,
            recipient=option.writer_address,
            transactions_len=1,
            transactions=transactions,
        );

        let option = Option(
            class_id=option.class_id,
            unit_id=option.unit_id,
            nonce=nonce,
            strike=option.strike,
            amount=option.amount,
            expiration=option.expiration,
            exponentiation=option.exponentiation,
            premium=option.premium,
            created=option.created,
            writer_address=option.writer_address,
            buyer_address=option.buyer_address,
            is_covered=option.is_covered,
            is_active=FALSE,
        );
        options.write(nonce, option);
        OptionRedeemed.emit(option);

        ReentrancyGuard.finish(nonce);

        return ();
    }

    //
    // Asks (offers)
    //

    func create_offer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, strike: felt, amount: felt, expiration: felt,
        ) {
        with_attr error_message("create_offer: details could not be zeros") {
            assert_not_zero(strike);
            assert_not_zero(amount);
            assert_not_zero(expiration);
        }

        // @notice Initiating the full collateralization of the call option
        // @notice Currently it's full covered call (will change in next versions)
        let (nonce: felt) = create_nonce();
        let (current_timestamp: felt) = get_block_timestamp();
        let (caller_address: felt) = get_caller_address();
        let (optio_address: felt) = optio_standard.read();
        let (pool_address: felt) = optio_pool.read();
        let (unit_id: felt) = IOptio.getLatestUnit(contract_address=optio_address, class_id=class_id);

        // @dev The batch here always contains a single micro-transaction
        // @dev But in practice a batch can contain hundreds of micro-transactions
        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, amount);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=caller_address,
            recipient=pool_address,
            transactions_len=1,
            transactions=transactions,
        );

        let offer = Offer(
            class_id=class_id,
            unit_id=unit_id,
            nonce=nonce,
            strike=strike,
            amount=amount,
            expiration=expiration,
            exponentiation=1,
            created=current_timestamp,
            writer_address=caller_address,
            is_matched=FALSE,
            is_active=TRUE,
        );
        offers.write(nonce, offer);

        // @dev Ready to get matched, emitting event for ME
        OfferCreated.emit(offer);

        return ();
    }

    func cancel_offer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            class_id: felt, unit_id: felt, nonce: felt, amount: felt
        ) {
        alloc_locals;

        let (offer: Offer) = offers.read(nonce);
        let (optio_address: felt) = optio_standard.read();
        let (pool_address: felt) = optio_pool.read();
        let (caller_address: felt) = get_caller_address();

        with_attr error_message("cancel_offer: only writer can cancel") {
            assert caller_address = offer.writer_address;
        }

        with_attr error_message("cancel_offer: offer was matched or not active") {
            assert offer.is_active = TRUE;
            assert offer.is_matched = FALSE;
        }

        ReentrancyGuard.start(nonce);

        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, amount);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=pool_address,
            recipient=caller_address,
            transactions_len=1,
            transactions=transactions,
        );

        let offer = Offer(
            class_id=offer.class_id,
            unit_id=offer.unit_id,
            nonce=nonce,
            strike=offer.strike,
            amount=offer.amount,
            expiration=offer.expiration,
            exponentiation=offer.exponentiation,
            created=offer.created,
            writer_address=offer.writer_address,
            is_matched=offer.is_matched,
            is_active=FALSE,
        );
        offers.write(nonce, offer);
        OfferCancelled.emit(offer);

        ReentrancyGuard.finish(nonce);

        return ();
    }

    func write_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            nonce: felt,
            class_id: felt,
            writer_address: felt,
            buyer_address: felt,
            premium: felt,
            metadata_ids_len: felt,
            metadata_ids: felt*,
            values_len: felt,
            values: Values*,
        ) {
        alloc_locals;

        with_attr error_message("write_option: got zero inputs lengths") {
            assert_not_zero(metadata_ids_len);
            assert_not_zero(values_len);
        }

        ReentrancyGuard.start(nonce);

        let (optio_address: felt) = optio_standard.read();
        let (pool_address: felt) = optio_pool.read();
        let (vault_address: felt) = optio_vault.read();
        let (offer: Offer) = offers.read(nonce);
        let (current_timestamp) = get_block_timestamp();

        with_attr error_message("write_option: writer's addresses don't match") {
            assert writer_address = offer.writer_address;
        }

        with_attr error_message("write_option: offer is already matched") {
            assert offer.is_matched = FALSE;
            assert offer.is_active = TRUE;
        }

        let (prev_unit_id) = IOptio.getLatestUnit(contract_address=optio_address, class_id=class_id);
        let unit_id = prev_unit_id + 1;

        // @notice Transferring the premium from a buyer to a writer
        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, premium);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=buyer_address,
            recipient=offer.writer_address,
            transactions_len=1,
            transactions=transactions,
        );

        // @notice Transferring the collateral from Optio pool to the Optio vault
        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, offer.amount);
        IOptio.transferFrom(
            contract_address=optio_address,
            sender=pool_address,
            recipient=vault_address,
            transactions_len=1,
            transactions=transactions,
        );

        // @dev Creating the actual option
        IOptio.createUnit(
            contract_address=optio_address,
            class_id=class_id,
            unit_id=unit_id,
            metadata_ids_len=metadata_ids_len,
            metadata_ids=metadata_ids,
            values_len=values_len,
            values=values
        );
        let option = Option(
            class_id=offer.class_id,
            unit_id=offer.unit_id,
            nonce=nonce,
            strike=offer.strike,
            amount=offer.amount,
            expiration=current_timestamp + offer.expiration,
            exponentiation=offer.exponentiation,
            premium=premium,
            created=current_timestamp,
            writer_address=writer_address,
            buyer_address=buyer_address,
            is_covered=TRUE,
            is_active=TRUE,
        );
        options.write(nonce, option);

        // @dev Minting LP tokens
        let (transactions: Transaction*) = alloc();
        assert transactions[0] = Transaction(class_id, unit_id, offer.amount);
        IOptio.issue(
            contract_address=optio_address,
            recipient=buyer_address,
            transactions_len=1,
            transactions=transactions
        );

        // @dev Disarming the offer
        let offer = Offer(
            class_id=offer.class_id,
            unit_id=offer.unit_id,
            nonce=nonce,
            strike=offer.strike,
            amount=offer.amount,
            expiration=offer.expiration,
            exponentiation=offer.exponentiation,
            created=offer.created,
            writer_address=writer_address,
            is_matched=TRUE,
            is_active=FALSE,
        );
        offers.write(nonce, offer);

        // @dev Emitting events for ME
        OptionCreated.emit(option);

        ReentrancyGuard.finish(nonce);

        return ();
    }
}

// Helpers

func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (nonce_value: felt) {
    let (nonce_value) = nonce.read();
    return (nonce_value=nonce_value);
}

func update_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(new_nonce: felt) -> () {
    nonce.write(new_nonce);
    return ();
}

func create_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (nonce_value: felt) {
    let (prev_nonce: felt) = get_nonce();
    tempvar new_nonce = prev_nonce + 1;
    update_nonce(new_nonce);
    return (nonce_value=new_nonce);
}

func calculate_profit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        current_price: felt, strike_price: felt, amount: felt, decimals: felt
    ) -> (buyer_profit: felt, writer_return: felt) {
    with_attr error_message("calculate_profit: inputs can't be zeros") {
        assert_not_zero(current_price);
        assert_not_zero(strike_price);
        assert_not_zero(amount);
    }
    with_attr error_message("calculate_profit: strike is larger than actual price") {
        assert_lt(strike_price, current_price);
    }

    let (normalizer: felt) = pow(10, decimals);
    let strike_price = strike_price * normalizer;
    let delta = current_price - strike_price;
    let surplus = delta * amount;
    let (buyer_profit, _) = unsigned_div_rem(surplus, current_price);

    with_attr error_message("calculate_profit: expected buyer_profit > 0, got {buyer_profit}") {
        assert_not_zero(buyer_profit);
    }
    let writer_return = amount - buyer_profit;

    return (buyer_profit, writer_return);
}

func felt_to_uint{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (value: felt) -> (value: Uint256) {
    let (high, low) = split_felt(value);
    tempvar res: Uint256;
    res.high = high;
    res.low = low;
    return (value=res);
}