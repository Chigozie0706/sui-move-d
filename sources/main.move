module dacade_deepbook::disaster_mgmt {
    use std::string::{String}; 
    use sui::coin::{Coin, split, put, take};
    use sui::balance::{Balance, zero};
    use sui::sui::SUI;
    use sui::event;

    /// Define errors
    const ONLYOWNER: u64 = 0;
    const INSUFFICIENTBALANCE: u64 = 1;
    

    /// Relief Center Struct
    public struct ReliefCenter has store, key {
        id: UID,
        name: String,
        balance: Balance<SUI>,
    }

    /// Admin Capability
    public struct AdminCap has key {
        id: UID,
        center_id: ID,
    }

    /// Events for transparency
    public struct DonationReceived has copy, drop {
        donor: address,
        amount: u64,
        center_id: ID,
    }

    public struct FundsTransferred has copy, drop {
        from_center_id: ID,
        to_center_id: ID,
        amount: u64,
    }

    public struct FundsWithdrawn has copy, drop {
        center_id: ID,
        amount: u64,
        recipient: address,
    }

    /// Create a new Relief Center
    public entry fun create_relief_center(
    name: String,
    ctx: &mut TxContext
) {
    let id = object::new(ctx);
    let center_id = object::uid_to_inner(&id); // Create center_id from id here.

    let center = ReliefCenter {
        id, // Use the original id for the ReliefCenter struct.
        name,
        balance: zero<SUI>(),
    };

    let admin_cap = AdminCap {
        id: object::new(ctx), // Generate a new UID for AdminCap.
        center_id, // Use the derived center_id here.
    };

    transfer::transfer(admin_cap, tx_context::sender(ctx));
    transfer::share_object(center);
}


    /// Donate funds to a Relief Center
    public entry fun donate_funds(
    center: &mut ReliefCenter,
    donation: &mut Coin<SUI>,
    ctx: &mut TxContext
) {
    let donation_amount = donation.value(); // Get the amount to donate.
    let split_donation = donation.split(donation_amount, ctx); // Split the coin.

    put(&mut center.balance, split_donation); // Add the split donation to the center's balance.

    event::emit(DonationReceived {
        donor: tx_context::sender(ctx),
        amount: donation_amount,
        center_id: object::uid_to_inner(&center.id),
    });
}


    /// Transfer funds between Relief Centers
    public entry fun transfer_funds_between_centers(
        from_center: &mut ReliefCenter,
        to_center: &mut ReliefCenter,
        amount: u64,
        owner: &AdminCap,
        ctx: &mut TxContext
    ) {
        assert!(
            &owner.center_id == object::uid_as_inner(&from_center.id),
            ONLYOWNER
        );
        assert!(amount > 0 && amount <= from_center.balance.value(), INSUFFICIENTBALANCE);

        let transfer_amount = take(&mut from_center.balance, amount, ctx);
        put(&mut to_center.balance, transfer_amount);

        event::emit(FundsTransferred {
            from_center_id: object::uid_to_inner(&from_center.id),
            to_center_id: object::uid_to_inner(&to_center.id),
            amount,
        });
    }

    /// Withdraw funds from a Relief Center
    public entry fun withdraw_funds(
        center: &mut ReliefCenter,
        amount: u64,
        recipient: address,
        owner: &AdminCap,
        ctx: &mut TxContext
    ) {
        assert!(
            &owner.center_id == object::uid_as_inner(&center.id),
            ONLYOWNER
        );
        assert!(amount > 0 && amount <= center.balance.value(), INSUFFICIENTBALANCE);

        let withdraw_amount = take(&mut center.balance, amount, ctx);
        transfer::public_transfer(withdraw_amount, recipient);

        event::emit(FundsWithdrawn {
            center_id: object::uid_to_inner(&center.id),
            amount,
            recipient,
        });
    }

    /// Get the balance of a Relief Center
    public fun get_center_balance(center: &ReliefCenter): u64 {
        center.balance.value()
    }
}

