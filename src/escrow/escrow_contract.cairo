#[starknet::contract]
pub mod EscrowContract {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, storage::Map, contract_address_const};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};
    use starknet::get_block_timestamp;
    use core::starknet::{get_caller_address, get_contract_address};
    use crate::escrow::{types::Escrow, types::Milestone, errors::Errors};
    use crate::interface::iescrow::{IEscrow};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        depositor: ContractAddress,
        beneficiary: ContractAddress,
        arbiter: ContractAddress,
        time_frame: u64,
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
        deposit_time: Map::<u64, u64>,
        // Track the funded escrows. Start as false and is setted to true when successfully funds.
        escrow_funded: Map::<u64, bool>,
        milestone_count: u64,
        // mapping to track milestones
        milestones: Map::<u64, Milestone>,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        DepositorApproved: DepositorApproved,
        ArbiterApproved: ArbiterApproved,
        EscrowInitialized: EscrowInitialized,
        EscrowFunded: EscrowFunded,
        EscrowRefunded: EscrowRefunded,
        FundsReleased: FundsReleased,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DepositorApproved {
        pub depositor: ContractAddress,
        pub escrow_id: u64,
        pub time_of_approval: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArbiterApproved {
        pub arbiter: ContractAddress,
        pub escrow_id: u64,
        pub time_of_approval: u64,
    }

    // Event for escrow initialization
    #[derive(Drop, starknet::Event)]
    pub struct EscrowInitialized {
        pub escrow_id: u64,
        pub beneficiary: ContractAddress,
        pub provider: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EscrowRefunded {
        pub escrow_id: u64,
        pub depositor: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }


    #[derive(Drop, starknet::Event)]
    pub struct EscrowFunded {
        pub depositor: ContractAddress,
        pub amount: u256,
        pub escrow_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RefundEscrow {
        pub depositor: ContractAddress,
        pub amount: u256,
        pub escrow_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsReleased {
        pub escrow_id: u64,
        pub beneficiary: ContractAddress,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        beneficiary: ContractAddress,
        depositor: ContractAddress,
        arbiter: ContractAddress,
    ) {
        self.beneficiary.write(beneficiary);
        self.depositor.write(depositor);
        self.arbiter.write(arbiter);
    }

    #[abi(embed_v0)]
    impl EscrowImpl of IEscrow<ContractState> {
        fn get_escrow_details(ref self: ContractState, escrow_id: u64) -> Escrow {
            // Validate if the escrow exists
            let exists = self.escrow_exists.read(escrow_id);
            assert(exists, Errors::ESCROW_NOT_FOUND);

            let client_address = self.client_address.read();
            let provider_address = self.provider_address.read();
            let amount = self.escrow_amounts.read(escrow_id);
            let balance = self.balance.read();

            let escrow = Escrow {
                client_address: client_address,
                provider_address: provider_address,
                amount: amount,
                balance: balance,
            };
            return escrow;
        }

        fn refundTimer(ref self: ContractState, escrow_id: u64, refund_period: u64) {
            let caller = get_caller_address();
            let depositor = self.depositor.read();
            assert(caller == depositor, Errors::UNAUTHORIZED_CALLER);

            let exists = self.escrow_exists.read(escrow_id);
            assert(exists, Errors::ESCROW_NOT_FOUND);

            let approved = self.arbiter_approve.read(depositor);
            assert(!approved, Errors::ALREADY_APPROVED);

            let deposit_time = self.deposit_time.read(escrow_id);

            let current_time = get_block_timestamp();
            assert(current_time >= deposit_time + refund_period, Errors::TIMER_NOT_EXPIRED);

            let amount = self.escrow_amounts.read(escrow_id);
            assert(amount > 0, Errors::INVALID_AMOUNT);

            let token_address = self.client_address.read();
            let mut erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer(depositor, amount);

            self.balance.write(self.balance.read() - amount);
            self.escrow_exists.write(escrow_id, false);
            self.escrow_amounts.write(escrow_id, 0);

            self
                .emit(
                    Event::EscrowRefunded(
                        EscrowRefunded {
                            escrow_id, depositor, amount, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        // Function for depositor to approve a specific escrow
        fn depositor_approve(ref self: ContractState, escrow_id: u64) {
            let caller = get_caller_address();
            let depositor = self.depositor.read();

            // Ensure only the depositor can call this function
            assert(caller == depositor, Errors::UNAUTHORIZED_CALLER);

            // Ensure the escrow exists
            let exists = self.escrow_exists.read(escrow_id);
            assert(exists, Errors::ESCROW_NOT_FOUND);

            // Ensure the escrow is funded
            let is_funded = self.escrow_funded.read(escrow_id);
            assert(is_funded, Errors::ESCROW_NOT_FUNDED);

            // Set approval
            self.depositor_approve.write(depositor, true);
            let timestamp = get_block_timestamp();

            // Emit the event
            self
                .emit(
                    DepositorApproved {
                        depositor: depositor, escrow_id: escrow_id, time_of_approval: timestamp,
                    },
                );
        }

        // Function for arbiter to approve a specific escrow
        fn arbiter_approve(ref self: ContractState, escrow_id: u64) {
            let caller = get_caller_address();
            let arbiter = self.arbiter.read();

            // Ensure only the arbiter can call this function
            assert(caller == arbiter, Errors::UNAUTHORIZED_CALLER);

            // Ensure the escrow exists
            let exists = self.escrow_exists.read(escrow_id);
            assert(exists, Errors::ESCROW_NOT_FOUND);

            // Ensure the escrow is funded
            let is_funded = self.escrow_funded.read(escrow_id);
            assert(is_funded, Errors::ESCROW_NOT_FUNDED);

            // Set approval
            self.arbiter_approve.write(arbiter, true);
            let timestamp = get_block_timestamp();

            // Emit the event
            self
                .emit(
                    ArbiterApproved {
                        arbiter: arbiter, escrow_id: escrow_id, time_of_approval: timestamp,
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
            self.beneficiary.write(beneficiary);
            self.provider_address.write(provider_address);
            // Initialize funded status as false
            self.escrow_funded.write(escrow_id, false);

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

        // add milestone for escrows to help in tracking
        fn add_milestone(
            ref self: ContractState, description: ByteArray, amount: u256, dueDate: u256,
        ) {
            assert(amount > 0, 'amount too low');
            let milestone_id: u64 = self.milestone_count.read() + 1;

            let milestone: Milestone = Milestone {
                id: milestone_id,
                description: description,
                amount: amount,
                dueDate: dueDate,
                isCompleted: false,
                isApprovedDepositor: false,
                isApprovedBeneficiary: false,
                isPaid: false,
            };

            self.milestones.write(milestone_id, milestone)
        }

        fn request_milestone_payment(
            ref self: ContractState, id: u64, token_address: ContractAddress,
        ) -> bool {
            let mut milestone: Milestone = self.milestones.read(id);

            assert(!milestone.isPaid, 'Milestone has been paid');
            assert(milestone.isApprovedBeneficiary, 'Milestone must be approved');
            assert(milestone.isApprovedDepositor, 'Milestone must be approved');
            assert(milestone.isCompleted, 'Milestone must be completed');

            let milestone_amount = milestone.amount;

            let token = IERC20Dispatcher { contract_address: token_address };
            let caller_address = get_caller_address();
            milestone.isPaid = true;

            token.transfer(caller_address, milestone_amount);

            return true;
        }

        fn fund_escrow(
            ref self: ContractState, escrow_id: u64, amount: u256, token_address: ContractAddress,
        ) {
            // Check if escrow exists
            assert(self.escrow_exists.read(escrow_id), 'Escrow does not exist.');

            // Setting needed variables
            let depositor = self.depositor.read();
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();
            let expected_amount = self.escrow_amounts.read(escrow_id);

            // Make an assert to check if the caller address is the same as the depositor address.
            assert(depositor == caller_address, 'Only depositor can fund.');

            // Check that the correct amount was sent.
            assert(amount >= expected_amount, 'Amount is less than expected');

            // First modify in-contract state to avoid reentrancy attacks
            // Set escrow to funded
            self.escrow_funded.write(escrow_id, true);

            // Update contract balance
            let current_balance = self.balance.read();
            self.balance.write(current_balance + amount);

            // Use the OpenZeppelin ERC20 contract to transfer the funds from the caller address to
            // the escrow contract.
            let token = IERC20Dispatcher { contract_address: token_address };
            token.transfer_from(caller_address, contract_address, amount);

            // Emit Escrow funded Event
            self.emit(EscrowFunded { depositor, amount, escrow_address: contract_address });
        }

        fn release_funds(ref self: ContractState, escrow_id: u64, token_address: ContractAddress) {
            let depositor = self.depositor.read();
            let arbiter = self.arbiter.read();
            let beneficiary = self.beneficiary.read();
            let contract_address = get_contract_address();

            // Ensure the escrow exists
            let exists = self.escrow_exists.read(escrow_id);
            assert(exists, Errors::ESCROW_NOT_FOUND);

            // Ensure the escrow is funded
            let is_funded = self.escrow_funded.read(escrow_id);
            assert(is_funded, Errors::ESCROW_NOT_FUNDED);

            // Ensure both depositor and arbiter have approved
            let depositor_approved = self.depositor_approve.read(depositor);
            let arbiter_approved = self.arbiter_approve.read(arbiter);
            assert(depositor_approved, Errors::DEPOSITOR_NOT_APPROVED);
            assert(arbiter_approved, Errors::ARBITER_NOT_APPROVED);

            // Get the escrow amount
            let amount = self.escrow_amounts.read(escrow_id);
            let current_balance = self.balance.read();
            assert(current_balance >= amount, Errors::INSUFFICIENT_BALANCE);

            // Deduct from contract balance and mark escrow as completed
            self.balance.write(current_balance - amount);
            self.escrow_funded.write(escrow_id, false);
            self.escrow_exists.write(escrow_id, false);

            // Get the ERC-20 token and transfer from contract to beneficiary
            let token = IERC20Dispatcher { contract_address: token_address };

            // The escrow contract calls `transfer` (not transfer_from) to send funds to the
            // beneficiary since the tokens are already in the contract
            token.transfer(beneficiary, amount);

            // Emit the funds released event
            self.emit(FundsReleased { escrow_id, beneficiary, amount });
        }

        fn get_depositor(self: @ContractState) -> ContractAddress {
            self.depositor.read()
        }

        fn get_beneficiary(self: @ContractState) -> ContractAddress {
            self.beneficiary.read()
        }

        fn get_arbiter(self: @ContractState) -> ContractAddress {
            self.arbiter.read()
        }

        fn is_escrow_funded(self: @ContractState, escrow_id: u64) -> bool {
            self.escrow_funded.read(escrow_id)
        }

        fn get_balance(self: @ContractState) -> u256 {
            self.balance.read()
        }

        fn get_escrow_amount(self: @ContractState, escrow_id: u64) -> u256 {
            self.escrow_amounts.read(escrow_id)
        }

        fn check_approvals(self: @ContractState, escrow_id: u64) -> (bool, bool) {
            let depositor = self.depositor.read();
            let arbiter = self.arbiter.read();
            let depositor_approved = self.depositor_approve.read(depositor);
            let arbiter_approved = self.arbiter_approve.read(arbiter);
            (depositor_approved, arbiter_approved)
        }
    }
}
