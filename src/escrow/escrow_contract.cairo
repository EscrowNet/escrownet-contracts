#[starknet::contract]
mod EscrowContract {
    use starknet::{ContractAddress, storage::Map, contract_address_const};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,};
    use starknet::get_block_timestamp;
    use core::starknet::{get_caller_address, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


    #[storage]
    struct Storage {
        depositor: ContractAddress,
        benefeciary: ContractAddress,
        arbiter: ContractAddress,
        time_frame: u64,
        worth_of_asset: u256,
        depositor_approve: Map::<ContractAddress, bool>,
        arbiter_approve: Map::<ContractAddress, bool>,
        escrow_balance: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ApproveTransaction: ApproveTransaction,
        EscrowFunded: EscrowFunded,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ApproveTransaction {
        depositor: ContractAddress,
        approval: bool,
        time_of_approval: u64,
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

    fn fund_escrow(ref self: ContractState, amount: u256, token_address: ContractAddress ) {
        // seting needed variables
        let depositor = self.depositor.read();
        let caller_address = get_caller_address();
        let contract_address = get_contract_address();
        // Make an assert the check if the caller address is the same as the depositor address.
        assert(depositor==caller_address, 'Only depositor can fund.');
        // Use the OpenZeppelin ERC20 contract to transfer the fund from the caller address to the scrow contract.
        let token = IERC20Dispatcher { contract_address: token_address };
        token.transfer_from(caller_address, contract_address, amount);
        // Update the escrow's balance in the Storage 
        self.escrow_balance.write(self.escrow_balance.read() + amount);
        // Emit Escrow funded Event 
        self
            .emit(
                EscrowFunded {
                    depositor, amount, escrow_address:contract_address
                }
            );

    }
}
