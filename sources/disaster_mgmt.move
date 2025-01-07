module disaster_mgmt::disaster_mgmt {
    use std::string::{String};
    use sui::coin::{Coin, split, put, take};
    use sui::balance::{Balance, zero};
    use sui::sui::SUI;
    use sui::event;

    const ONLYOWNER: u64 = 0;
    const INSUFFICIENTBALANCE: u64 = 1;
    const INVALID_AMOUNT: u64 = 2;

    // Relief Center Struct: Stores information about a disaster relief center
    public struct ReliefCenter has store, key {
        id: UID,
        name: String,
        balance: Balance<SUI>,
        total_contributions: u64, // Track total contributions for yield calculations
        token_supply: u64, // Total supply of center tokens
    }

    // Admin Capability Struct: Grants administrative capabilities over a Relief Center
    public struct AdminCap has key {
        id: UID,
        center_id: ID,
    }

    // Relief Center Token: Represents a share of the Relief Center
    public struct ReliefToken has store, key {
        id: UID,
        center_id: ID,
        amount: u64,
    }

    // Events for transparency
    public struct DonationReceived has copy, drop {
        donor: address,
        amount: u64,
        center_id: ID,
        epoch: u64,
    }

    public struct FundsTransferred has copy, drop {
        from_center_id: ID,
        to_center_id: ID,
        amount: u64,
        epoch: u64,
    }

    public struct FundsWithdrawn has copy, drop {
        center_id: ID,
        amount: u64,
        recipient: address,
        epoch: u64,
    }

    public struct TokensMinted has copy, drop {
        donor: address,
        center_id: ID,
        amount: u64,
        tokens_issued: u64,
    }

    // Create a new Relief Center
    public entry fun create_relief_center(
        name: String,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let center_id = object::uid_to_inner(&id);

        let center = ReliefCenter {
            id,
            name,
            balance: zero<SUI>(),
            total_contributions: 0,
            token_supply: 0,
        };

        let admin_cap = AdminCap {
            id: object::new(ctx),
            center_id,
        };

        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(center);
    }

    // Donate funds and receive tokens
    public entry fun donate_and_mint_tokens(
        center: &mut ReliefCenter,
        donation: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let donation_amount = donation.value();
        assert!(donation_amount > 0, INVALID_AMOUNT);

        let split_donation = donation.split(donation_amount, ctx);
        put(&mut center.balance, split_donation);

        // Calculate tokens to mint (1:1 ratio for simplicity)
        let tokens_to_mint = donation_amount;

        let token = ReliefToken {
            id: object::new(ctx),
            center_id: object::uid_to_inner(&center.id),
            amount: tokens_to_mint,
        };

        transfer::transfer(token, tx_context::sender(ctx));

        // Update the total contributions and token supply
        center.total_contributions = center.total_contributions + donation_amount;
        center.token_supply = center.token_supply + tokens_to_mint;


        let current_epoch = tx_context::epoch(ctx);
        event::emit(DonationReceived {
            donor: tx_context::sender(ctx),
            amount: donation_amount,
            center_id: object::uid_to_inner(&center.id),
            epoch: current_epoch,
        });
        event::emit(TokensMinted {
            donor: tx_context::sender(ctx),
            center_id: object::uid_to_inner(&center.id),
            amount: donation_amount,
            tokens_issued: tokens_to_mint,
        });
    }

    // Transfer funds between Relief Centers
    public entry fun transfer_funds_between_centers(
        from_center: &mut ReliefCenter,
        to_center: &mut ReliefCenter,
        amount: u64,
        owner: &AdminCap,
        ctx: &mut TxContext
    ) {
        assert!(&owner.center_id == object::uid_as_inner(&from_center.id), ONLYOWNER);
        assert!(amount > 0 && amount <= from_center.balance.value(), INSUFFICIENTBALANCE);

        let transfer_amount = take(&mut from_center.balance, amount, ctx);
        put(&mut to_center.balance, transfer_amount);

        let current_epoch = tx_context::epoch(ctx);
        event::emit(FundsTransferred {
            from_center_id: object::uid_to_inner(&from_center.id),
            to_center_id: object::uid_to_inner(&to_center.id),
            amount,
            epoch: current_epoch,
        });
    }

    // Withdraw funds from a Relief Center
    public entry fun withdraw_funds(
        center: &mut ReliefCenter,
        amount: u64,
        recipient: address,
        owner: &AdminCap,
        ctx: &mut TxContext
    ) {
        assert!(&owner.center_id == object::uid_as_inner(&center.id), ONLYOWNER);
        assert!(amount > 0 && amount <= center.balance.value(), INSUFFICIENTBALANCE);

        let withdraw_amount = take(&mut center.balance, amount, ctx);
        transfer::public_transfer(withdraw_amount, recipient);

        let current_epoch = tx_context::epoch(ctx);
        event::emit(FundsWithdrawn {
            center_id: object::uid_to_inner(&center.id),
            amount,
            recipient,
            epoch: current_epoch,
        });
    }

    // Get the balance of a Relief Center
    public fun get_center_balance(center: &ReliefCenter): u64 {
        center.balance.value()
    }

    // Get total contributions for yield distribution
    public fun get_total_contributions(center: &ReliefCenter): u64 {
        center.total_contributions
    }
}
