use starknet::{ContractAddress};

#[starknet::contract]
mod EscrowContract {
    use starknet::{ContractAddress, storage::Map, contract_address_const};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,};
    use starknet::get_block_timestamp;
    use core::starknet::{get_caller_address};
    //Import the interface
    use escrownet_contract::interface::IEscrow;

    #[storage]
    struct Storage {
        depositor: ContractAddress,
        benefeciary: ContractAddress,
        arbiter: ContractAddress,
        time_frame: u64,
        worth_of_asset: u256,
        depositor_approve: Map::<ContractAddress, bool>,
        arbiter_approve: Map::<ContractAddress, bool>,
        // Track whether an escrow ID has been used
        escrow_exists: Map::<u64, bool>,
        // Store escrow amounts
        escrow_amounts: Map::<u64, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ApproveTransaction: ApproveTransaction,
        EscrowInitialized: EscrowInitialized,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ApproveTransaction {
        depositor: ContractAddress,
        approval: bool,
        time_of_approval: u64,
    }

    // New event for escrow initialization
    #[derive(Drop, starknet::Event)]
    struct EscrowInitialized {
        escrow_id: u64,
        beneficiary: ContractAddress,
        provider: ContractAddress,
        amount: u256,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        benefeciary: ContractAddress,
        depositor: ContractAddress,
        arbiter: ContractAddress
    ) {
        self.benefeciary.write(benefeciary);
        self.depositor.write(depositor);
        self.arbiter.write(arbiter);
    }


    fn approve(ref self: ContractState, benefeciary: ContractAddress) {
        let caller = get_caller_address();
        // check if the address is a depositor
        let mut address = self.depositor.read();
        // check if address exist
        if address != 0.try_into().unwrap() {
            // address type is a depositor
            address = caller
        }
        // check if address is a benificary
        address = self.benefeciary.read();

        if address != 0.try_into().unwrap() {
            // address type is a beneficary
            address = caller
        }
        // map address to true
        self.depositor_approve.entry(address).write(true);
        let timestamp = get_block_timestamp();

        // Emit the event
        self
            .emit(
                ApproveTransaction {
                    depositor: address, approval: true, time_of_approval: timestamp,
                }
            );
    }

    /// Initialize a new escrow with the given parameters
    /// # Arguments
    /// * escrow_id - Unique identifier for the escrow
    /// * beneficiary - Address of the beneficiary
    /// * provider_address - Address of the service provider
    /// * amount - Amount to be held in escrow
    #[external(v0)]
    fn initialize_escrow(
            ref self: ContractState,
            escrow_id: u64,
            beneficiary: ContractAddress,
            provider_address: ContractAddress,
            amount: u256
        ) {
            // Additional validation for addresses
            assert(beneficiary != contract_address_const::<'0x0'>() , 'Invalid beneficiary address');
            assert(provider_address != contract_address_const::<'0x0'>(), 'Invalid provider address');
            let caller = get_caller_address();
            
            // Ensure caller is authorized (this might need adjustment based on requirements)
            assert(caller == self.depositor.read(), 'Unauthorized caller');

            // Check if escrow already exists
            let exists = self.escrow_exists.read(escrow_id);
            assert(!exists, 'Escrow ID already exists');

            // Basic validation
            assert(amount > 0, 'Amount must be positive');
            assert(beneficiary != provider_address, 'Invalid addresses');

            // Store escrow details
            self.escrow_exists.write(escrow_id, true);
            self.escrow_amounts.write(escrow_id, amount);
            self.worth_of_asset.write(amount);

            // Emit initialization event
            self.emit(
                Event::EscrowInitialized (
                    EscrowInitialized{
                    escrow_id,
                    beneficiary,
                    provider: provider_address,
                    amount,
                    timestamp: get_block_timestamp(),
                })
            );
    
    }
}
