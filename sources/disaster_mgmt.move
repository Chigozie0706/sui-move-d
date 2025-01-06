module disaster_mgmt::disaster_mgmt {
    use std::string::{String}; 
    use sui::coin::{Coin, split, put, take};
    use sui::balance::{Balance, zero};
    use sui::sui::SUI;
    use sui::event;

    // Define custom error codes
    const ONLYOWNER: u64 = 0; 
    const INSUFFICIENTBALANCE: u64 = 1; 

    // Relief Center Struct: Stores information about a disaster relief center
    public struct ReliefCenter has store, key {
        id: UID,  
        name: String,  
        balance: Balance<SUI>, 
    }

    // Admin Capability Struct: Grants administrative capabilities over a Relief Center
    public struct AdminCap has key {
        id: UID,  
        center_id: ID, 
    }

    // Events for transparency: Used for logging actions on the blockchain
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

    // Create a new Relief Center
    public entry fun create_relief_center(
        name: String,  
        ctx: &mut TxContext  
    ) {
        let id = object::new(ctx);  
        let center_id = object::uid_to_inner(&id);  

        // Initialize a new ReliefCenter object
        let center = ReliefCenter {
            id,  
            name,  
            balance: zero<SUI>(), 
        };

        // Create the AdminCap associated with the relief center
        let admin_cap = AdminCap {
            id: object::new(ctx),  
            center_id,  
        };

        // Transfer the admin capability to the sender
        transfer::transfer(admin_cap, tx_context::sender(ctx));
        
        // Share the ReliefCenter object, making it available on-chain
        transfer::share_object(center);
    }

    // Donate funds to a Relief Center
    public entry fun donate_funds(
        center: &mut ReliefCenter,  
        donation: &mut Coin<SUI>,  
        ctx: &mut TxContext  
    ) {
        let donation_amount = donation.value();  
        let split_donation = donation.split(donation_amount, ctx);  

        // Add the split donation to the center's balance
        put(&mut center.balance, split_donation); 

        let current_epoch = tx_context::epoch(ctx);

        // Emit a donation received event for transparency
        event::emit(DonationReceived {
            donor: tx_context::sender(ctx),  
            amount: donation_amount,  
            center_id: object::uid_to_inner(&center.id),  
            epoch: current_epoch
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
        // Ensure that the sender is the owner of the from_center
        assert!(&owner.center_id == object::uid_as_inner(&from_center.id), ONLYOWNER);
        // Ensure that the center has enough balance for the transfer
        assert!(amount > 0 && amount <= from_center.balance.value(), INSUFFICIENTBALANCE);

        // Take the funds from the sender's balance and transfer to the recipient center
        let transfer_amount = take(&mut from_center.balance, amount, ctx);
        put(&mut to_center.balance, transfer_amount);

        let current_epoch = tx_context::epoch(ctx);

        // Emit a funds transferred event
        event::emit(FundsTransferred {
            from_center_id: object::uid_to_inner(&from_center.id),  
            to_center_id: object::uid_to_inner(&to_center.id),  
            amount, 
            epoch: current_epoch 
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
        // Ensure that the sender is the owner of the center
        assert!(&owner.center_id == object::uid_as_inner(&center.id), ONLYOWNER);
        // Ensure the center has enough funds for the withdrawal
        assert!(amount > 0 && amount <= center.balance.value(), INSUFFICIENTBALANCE);

        // Take the withdrawal amount from the center's balance and transfer it to the recipient
        let withdraw_amount = take(&mut center.balance, amount, ctx);
        transfer::public_transfer(withdraw_amount, recipient);

        let current_epoch = tx_context::epoch(ctx);

        // Emit a funds withdrawn event for transparency
        event::emit(FundsWithdrawn {
            center_id: object::uid_to_inner(&center.id),  
            amount,  
            recipient,  
            epoch: current_epoch, 
        });
    }

    // Get the balance of a Relief Center...
    public fun get_center_balance(center: &ReliefCenter): u64 {
        center.balance.value()  
    }
    
}