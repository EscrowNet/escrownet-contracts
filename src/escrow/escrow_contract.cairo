#[starknet::contract]
mod EscrowContract {
    use starknet::event::EventEmitter;
    use core::num::traits::Zero;
    use starknet::{ContractAddress, storage::Map};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,};
    use starknet::get_block_timestamp;
    use core::starknet::{get_caller_address};
    use crate::interface::ierc20:: {IERC20Dispatcher, IERC20DispatcherTrait};


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
        escrow_exists: Map::<u64, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ApproveTransaction: ApproveTransaction,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ApproveTransaction {
        depositor: ContractAddress,
        approval: bool,
        time_of_approval: u64,
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

    #[external(v0)]
    fn distribute_escrow_earnings(ref self: ContractState, escrow_id: u64, release_address: ContractAddress){
        assert(escrow_id == self.escrow_id.read(), 'Escrow Contract is not valid');
        
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
        let transfer_result = token_contract.transfer_from(depositor, release_address, self.worth_of_asset.read());
        assert(transfer_result, 'Token transfer failed');

        // Update balance after successful transfer
        self.balance.write(0);
    }
}
