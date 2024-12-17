module dacade_deepbook::disaster_mgmt {
    use std::string::{String}; 
    use sui::coin::{Coin, split, put, take};
    use sui::balance::{Balance, zero};
    use sui::sui::SUI;
    use sui::event;

    // Define custom error codes
    const ONLYOWNER: u64 = 0; // Error when the caller is not the owner of the center
    const INSUFFICIENTBALANCE: u64 = 1; // Error when the center does not have enough funds

    // Relief Center Struct: Stores information about a disaster relief center
    public struct ReliefCenter has store, key {
        id: UID,  // Unique identifier for the center
        name: String,  // Name of the relief center
        balance: Balance<SUI>,  // The balance of funds in the relief center
    }

    // Admin Capability Struct: Grants administrative capabilities over a Relief Center
    public struct AdminCap has key {
        id: UID,  // Unique identifier for the admin capability
        center_id: ID,  // The ID of the relief center associated with the admin
    }

    // Events for transparency: Used for logging actions on the blockchain
    public struct DonationReceived has copy, drop {
        donor: address,  // Address of the donor
        amount: u64,  // Amount donated
        center_id: ID,  // ID of the relief center that received the donation
    }

    public struct FundsTransferred has copy, drop {
        from_center_id: ID,  // ID of the center sending funds
        to_center_id: ID,  // ID of the center receiving funds
        amount: u64,  // Amount of funds transferred
    }

    public struct FundsWithdrawn has copy, drop {
        center_id: ID,  // ID of the center withdrawing funds
        amount: u64,  // Amount of funds withdrawn
        recipient: address,  // Address of the recipient of the funds
    }

    // Create a new Relief Center
    public entry fun create_relief_center(
        name: String,  // Name of the new relief center
        ctx: &mut TxContext  // Transaction context
    ) {
        let id = object::new(ctx);  // Create a new object ID for the relief center
        let center_id = object::uid_to_inner(&id);  // Derive the center ID from the object ID

        // Initialize a new ReliefCenter object
        let center = ReliefCenter {
            id,  // Set the generated ID
            name,  // Set the name passed in
            balance: zero<SUI>(),  // Initialize the center with zero balance
        };

        // Create the AdminCap associated with the relief center
        let admin_cap = AdminCap {
            id: object::new(ctx),  // Generate a new UID for AdminCap
            center_id,  // Associate the center ID
        };

        // Transfer the admin capability to the sender
        transfer::transfer(admin_cap, tx_context::sender(ctx));
        
        // Share the ReliefCenter object, making it available on-chain
        transfer::share_object(center);
    }

    // Donate funds to a Relief Center
    public entry fun donate_funds(
        center: &mut ReliefCenter,  // Reference to the relief center receiving funds
        donation: &mut Coin<SUI>,  // The donation coin to be transferred
        ctx: &mut TxContext  // Transaction context
    ) {
        let donation_amount = donation.value();  // Get the donation amount
        let split_donation = donation.split(donation_amount, ctx);  // Split the coin (if needed)

        // Add the split donation to the center's balance
        put(&mut center.balance, split_donation); 

        // Emit a donation received event for transparency
        event::emit(DonationReceived {
            donor: tx_context::sender(ctx),  // Address of the donor
            amount: donation_amount,  // Amount donated
            center_id: object::uid_to_inner(&center.id),  // ID of the center
        });
    }

    // Transfer funds between Relief Centers
    public entry fun transfer_funds_between_centers(
        from_center: &mut ReliefCenter,  // The center sending funds
        to_center: &mut ReliefCenter,  // The center receiving funds
        amount: u64,  // The amount to transfer
        owner: &AdminCap,  // The admin capability for authorization
        ctx: &mut TxContext  // Transaction context
    ) {
        // Ensure that the sender is the owner of the from_center
        assert!(&owner.center_id == object::uid_as_inner(&from_center.id), ONLYOWNER);
        // Ensure that the center has enough balance for the transfer
        assert!(amount > 0 && amount <= from_center.balance.value(), INSUFFICIENTBALANCE);

        // Take the funds from the sender's balance and transfer to the recipient center
        let transfer_amount = take(&mut from_center.balance, amount, ctx);
        put(&mut to_center.balance, transfer_amount);

        // Emit a funds transferred event
        event::emit(FundsTransferred {
            from_center_id: object::uid_to_inner(&from_center.id),  // ID of the sending center
            to_center_id: object::uid_to_inner(&to_center.id),  // ID of the receiving center
            amount,  // Amount transferred
        });
    }

    // Withdraw funds from a Relief Center
    public entry fun withdraw_funds(
        center: &mut ReliefCenter,  // The relief center from which funds are withdrawn
        amount: u64,  // The amount to withdraw
        recipient: address,  // The recipient address
        owner: &AdminCap,  // The admin capability for authorization
        ctx: &mut TxContext  // Transaction context
    ) {
        // Ensure that the sender is the owner of the center
        assert!(&owner.center_id == object::uid_as_inner(&center.id), ONLYOWNER);
        // Ensure the center has enough funds for the withdrawal
        assert!(amount > 0 && amount <= center.balance.value(), INSUFFICIENTBALANCE);

        // Take the withdrawal amount from the center's balance and transfer it to the recipient
        let withdraw_amount = take(&mut center.balance, amount, ctx);
        transfer::public_transfer(withdraw_amount, recipient);

        // Emit a funds withdrawn event for transparency
        event::emit(FundsWithdrawn {
            center_id: object::uid_to_inner(&center.id),  // ID of the center making the withdrawal
            amount,  // Amount withdrawn
            recipient,  // Address of the recipient
        });
    }

    // Get the balance of a Relief Center...
    public fun get_center_balance(center: &ReliefCenter): u64 {
        center.balance.value()  // Return the balance of the relief center
    }
    
}
