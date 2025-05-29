use escrownet_contract::interface::iescrow::IEscrowDispatcherTrait;
use starknet::ContractAddress;

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
fn test_initialize_escrow_with_zero_beneficiary_address() {
    let contract_address = __setup__();
    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let escrow_id: u64 = 10;
    let zero_address = starknet::contract_address_const::<0x0>();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 100;
    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    let result = escrow_contract_dispatcher
        .try_initialize_escrow(escrow_id, zero_address, provider_address, amount);

    assert(result.is_err(), 'Should revert for zero beneficiary address');
    let err = result.unwrap_err();
    assert(*err.at(0) == Errors::INVALID_BENEFICIARY_ADDRESS, *err.at(0));

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_initialize_escrow_with_beneficiary_equals_provider() {
    let contract_address = __setup__();
    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let escrow_id: u64 = 11;
    let address = starknet::contract_address_const::<0x123>();
    let amount: u256 = 100;
    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    let result = escrow_contract_dispatcher
        .try_initialize_escrow(escrow_id, address, address, amount);

    assert(result.is_err(), 'Should revert when beneficiary equals provider');
    let err = result.unwrap_err();
    assert(*err.at(0) == Errors::INVALID_ADDRESSES, *err.at(0));

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_initialize_escrow_with_zero_amount() {
    let contract_address = __setup__();
    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let escrow_id: u64 = 12;
    let beneficiary = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 0;
    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    let result = escrow_contract_dispatcher
        .try_initialize_escrow(escrow_id, beneficiary, provider_address, amount);

    assert(result.is_err(), 'Should revert for zero amount');
    let err = result.unwrap_err();
    assert(*err.at(0) == Errors::INVALID_AMOUNT, *err.at(0));

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_initialize_escrow_access_control_only_depositor() {
    let contract_address = __setup__();
    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let escrow_id: u64 = 13;
    let beneficiary = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 100;
    let not_depositor = ARBITER(); // Use arbiter as unauthorized caller

    start_cheat_caller_address(contract_address, not_depositor);

    let result = escrow_contract_dispatcher
        .try_initialize_escrow(escrow_id, beneficiary, provider_address, amount);

    assert(result.is_err(), 'Should revert for non-depositor caller');
    let err = result.unwrap_err();
    assert(*err.at(0) == Errors::UNAUTHORIZED_CALLER, *err.at(0));

    stop_cheat_caller_address(contract_address);
}
