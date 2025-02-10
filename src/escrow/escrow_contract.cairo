#[starknet::contract]
mod EscrowContract {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, storage::Map, contract_address_const};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};
    use starknet::get_block_timestamp;
    use core::starknet::{get_caller_address};
    use crate::escrow::{types::Escrow, errors::Errors};
    use crate::interface::iescrow::{IEscrow};

    #[storage]
    struct Storage {
        depositor: ContractAddress,
        benefeciary: ContractAddress,
        arbiter: ContractAddress,
        time_frame: u64, // #[view]
        worth_of_asset: u256,
        client_address: ContractAddress,
        provider_address: ContractAddress,
        balance: u256,
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
    pub struct EscrowInitialized {
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
        arbiter: ContractAddress,
    ) {
        self.benefeciary.write(benefeciary);
        self.depositor.write(depositor);
        self.arbiter.write(arbiter);
    }


    #[abi(embed_v0)]
    impl EscrowImpl of IEscrow<ContractState> {
        fn get_escrow_details(ref self: ContractState, escrow_id: u256) -> Escrow {
            // Validate if the escrow exists
            let depositor = self.depositor.read();
            assert(!depositor.is_zero(), Errors::ESCROW_NOT_FOUND);

            let client_address = self.client_address.read();
            let provider_address = self.provider_address.read();
            let amount = self.worth_of_asset.read();
            let balance = self.balance.read();

            let escrow = Escrow {
                client_address: client_address,
                provider_address: provider_address,
                amount: amount,
                balance: balance,
            };
            return escrow;
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

        fn initialize_escrow(
            ref self: ContractState,
            escrow_id: u64,
            beneficiary: ContractAddress,
            provider_address: ContractAddress,
            amount: u256
        ) {
            // Additional validation for addresses
            assert(
                beneficiary != contract_address_const::<'0x0'>(),
                Errors::INVALID_BENEFICIARY_ADDRESS
            );
            assert(
                provider_address != contract_address_const::<'0x0'>(),
                Errors::INVALID_PROVIDER_ADDRESS
            );
            let caller = get_caller_address();

            // Ensure caller is authorized (this might need adjustment based on requirements)
            assert(caller == self.depositor.read(), Errors::UNAUTHORIZED_CALLER);

            // Check if escrow already exists
            let exists = self.escrow_exists.read(escrow_id);
            assert(!exists, Errors::ESCROW_ID_ALREADY_EXISTS);

            // Basic validation
            assert(amount > 0, Errors::INVALID_AMOUNT);
            assert(beneficiary != provider_address, Errors::INVALID_ADDRESSES);

            // Store escrow details
            self.escrow_exists.write(escrow_id, true);
            self.escrow_amounts.write(escrow_id, amount);
            self.worth_of_asset.write(amount);

            // Emit initialization event
            self
                .emit(
                    Event::EscrowInitialized(
                        EscrowInitialized {
                            escrow_id,
                            beneficiary,
                            provider: provider_address,
                            amount,
                            timestamp: get_block_timestamp(),
                        }
                    )
                );
        }

        fn get_depositor(self: @ContractState) -> ContractAddress {
            self.depositor.read()
        }
    }
}
