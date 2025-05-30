use escrownet_contract::interface::iescrow::IEscrowDispatcherTrait;
use starknet::{ContractAddress, storage::Map, contract_address_const};

use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp, spy_events,
    EventSpyAssertionsTrait,
};
use escrownet_contract::interface::iescrow::{IEscrowDispatcher};
use escrownet_contract::escrow::errors::Errors;

fn BENEFICIARY() -> ContractAddress {
    'benefeciary'.try_into().unwrap()
}

fn DEPOSITOR() -> ContractAddress {
    'depositor'.try_into().unwrap()
}

fn ARBITER() -> ContractAddress {
    'arbiter'.try_into().unwrap()
}

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> ContractAddress {
    // deploy  Esrownet
    let escrow_class_hash = declare("EscrowContract").unwrap().contract_class();

    let mut escrow_constructor_calldata: Array<felt252> = array![];

    let benefeciary = BENEFICIARY();
    let depositor = DEPOSITOR();
    let arbiter = ARBITER();

    benefeciary.serialize(ref escrow_constructor_calldata);
    depositor.serialize(ref escrow_constructor_calldata);
    arbiter.serialize(ref escrow_constructor_calldata);

    let (escrow_contract_address, _) = escrow_class_hash
        .deploy(@escrow_constructor_calldata)
        .unwrap();

    return (escrow_contract_address);
}
#[test]
fn test_setup() {
    let contract_address = __setup__();

    println!("Deployed address: {:?}", contract_address);
}

#[test]
fn test_initialize_escrow() {
    let contract_address = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let mut spy = spy_events();

    // setup test data
    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == 250, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Invalid amount')]
fn test_initialize_zero_amount_should_fail() {
    let contract_address = __setup__();
    let escrow = IEscrowDispatcher { contract_address };
    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow.initialize_escrow(2, BENEFICIARY(), contract_address_const::<0x999>(), 0);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Escrow ID already exists')]
fn test_initialize_twice_same_id_should_fail() {
    let contract_address = __setup__();
    let escrow = IEscrowDispatcher { contract_address };
    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    let escrow_id = 3;
    let provider = contract_address_const::<0x111>();

    // First call should succeed
    escrow
        .initialize_escrow(escrow_id, BENEFICIARY(), provider, 100);

    // Second call should fail
    let result = escrow
        .initialize_escrow(escrow_id, BENEFICIARY(), provider, 100);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Unauthorized caller')]
fn test_initialize_wrong_caller_should_fail() {
    let contract_address = __setup__();
    let escrow = IEscrowDispatcher { contract_address };

    let wrong_caller = contract_address_const::<0xDEADBEEF>();
    start_cheat_caller_address(contract_address, wrong_caller);

    let result = escrow
        .initialize_escrow(4, BENEFICIARY(), contract_address_const::<0x888>(), 100);

    stop_cheat_caller_address(contract_address);
}







