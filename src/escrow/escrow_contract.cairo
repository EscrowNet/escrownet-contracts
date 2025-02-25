#[starknet::contract]
mod EscrowContract {
    use starknet::event::EventEmitter;
    use crate::interface::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use core::num::traits::Zero;
    use starknet::{ContractAddress, storage::Map, contract_address_const};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};
    use starknet::get_block_timestamp;
    use core::starknet::{get_caller_address, get_contract_address};
    use crate::escrow::{types::Escrow, errors::Errors};
    use crate::interface::iescrow::{IEscrow};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        escrow_id: u64,
        depositor: ContractAddress,
        benefeciary: ContractAddress,
        arbiter: ContractAddress,
        token_address: ContractAddress,
        time_frame: u64,
        worth_of_asset: u256,
        balance: u256,
        depositor_approve: Map::<ContractAddress, bool>,
        arbiter_approve: Map::<ContractAddress, bool>,
        escrow_exists: Map::<u64, bool>,
        escrow_amounts: Map::<u64, u256>,
        // Track the funded escrows. Start as false and is setted to true when successfully funds.
        escrow_funded: Map::<u64, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ApproveTransaction: ApproveTransaction,
        EscrowEarningsDistributed: EscrowEarningsDistributed,
        EscrowInitialized: EscrowInitialized,
        EscrowFunded: EscrowFunded
    }

    #[derive(Drop, starknet::Event)]
    pub struct ApproveTransaction {
        depositor: ContractAddress,
        approval: bool,
        time_of_approval: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EscrowEarningsDistributed {
        escrow_id: u64,
        release_address: ContractAddress,
        amount: u256
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


    #[derive(Drop, starknet::Event)]
    pub struct EscrowFunded {
        depositor: ContractAddress,
        amount: u256,
        escrow_address: ContractAddress,
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
        fn get_escrow_details(ref self: ContractState) -> Escrow {
            // Validate if the escrow exists
            let depositor = self.depositor.read();
            assert(!depositor.is_zero(), Errors::ESCROW_NOT_FOUND);

            let client_address = self.benefeciary.read();
            let provider_address = self.depositor.read();
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
                    },
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
            amount: u256,
        ) {
            // Additional validation for addresses
            assert(
                beneficiary != contract_address_const::<'0x0'>(),
                Errors::INVALID_BENEFICIARY_ADDRESS,
            );
            assert(
                provider_address != contract_address_const::<'0x0'>(),
                Errors::INVALID_PROVIDER_ADDRESS,
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
                        },
                    ),
                );
        }

        fn fund_escrow(
            ref self: ContractState, escrow_id: u64, amount: u256, token_address: ContractAddress,
        ) {
            // check if escrow exists
            assert(self.escrow_exists.entry(escrow_id).read(), 'Escrow not exists.');
            // seting needed variables
            let depositor = self.depositor.read();
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();
            let expected_amount = self.escrow_amounts.entry(escrow_id).read();
            // Make an assert the check if the caller address is the same as the depositor address.
            assert(depositor == caller_address, 'Only depositor can fund.');
            // Check that the correct amount was sended.
            assert(amount >= expected_amount, 'Amount is less than expected');

            //// First Modify in-contract state to avoid reentrancy attacks
            // Set escrow to funded
            self.escrow_funded.entry(escrow_id).write(true);

            // Use the OpenZeppelin ERC20 contract to transfer the fund from the caller address to
            // the scrow contract.
            let token = IERC20Dispatcher { contract_address: token_address };
            token.transfer_from(caller_address, contract_address, amount);
            // Emit Escrow funded Event
            self.emit(EscrowFunded { depositor, amount, escrow_address: contract_address });
        }


        fn get_depositor(self: @ContractState) -> ContractAddress {
            self.depositor.read()
        }


        fn get_beneficiary(self: @ContractState) -> ContractAddress {
            self.benefeciary.read()
        }
    }

    #[external(v0)]
    fn distribute_escrow_earnings(
        ref self: ContractState, escrow_id: u64, release_address: ContractAddress
    ) {
        assert(self.escrow_id.read() == escrow_id, 'Escrow Contract is not valid');

        let depositor_approved = self.depositor_approve.entry(self.depositor.read()).read();
        let arbiter_approved = self.arbiter_approve.entry(self.arbiter.read()).read();
        // Verify both approvals
        assert(depositor_approved && arbiter_approved, 'Escrow not approved');

        //Verify token validity
        let token_address = self.token_address.read();
        assert(!token_address.is_zero(), 'Invalid token address');

        //Verify if funds were already distributed or there is enough balance
        assert(self.balance.read() > 0, 'Funds already distributed');
        assert(self.balance.read() >= self.worth_of_asset.read(), 'Insufficient funds');

        // Create token dispatcher
        let token_contract = IERC20Dispatcher { contract_address: token_address };
        let depositor = self.depositor.read();

        // Transfer tokens
        let transfer_result = token_contract
            .transfer_from(depositor, release_address, self.worth_of_asset.read());
        assert(transfer_result, 'Token transfer failed');

        // Update balance after successful transfer
        self.balance.write(0);

        self
            .emit(
                EscrowEarningsDistributed {
                    escrow_id, release_address, amount: self.worth_of_asset.read()
                }
            );
    }
}
