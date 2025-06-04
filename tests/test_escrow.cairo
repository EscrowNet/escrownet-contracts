use escrownet_contract::interface::ierc20::IERC20DispatcherTrait;
use escrownet_contract::interface::iescrow::IEscrowDispatcherTrait;
use starknet::{ContractAddress, storage::Map, contract_address_const};

use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp, spy_events,
    EventSpyAssertionsTrait,
};
use escrownet_contract::interface::ierc20::{IERC20Dispatcher};
use escrownet_contract::interface::iescrow::{IEscrowDispatcher};
use escrownet_contract::escrow::errors::Errors;
use escrownet_contract::escrow::escrow_contract::EscrowContract;

fn BENEFICIARY() -> ContractAddress {
    'benefeciary'.try_into().unwrap()
}

fn DEPOSITOR() -> ContractAddress {
    'depositor'.try_into().unwrap()
}

fn ARBITER() -> ContractAddress {
    'arbiter'.try_into().unwrap()
}

fn OTHER() -> ContractAddress {
    'other'.try_into().unwrap()
}

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> (ContractAddress, ContractAddress) {
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

    // deploy mock USDT
    let usdt_contract = declare("USDT").unwrap().contract_class();
    let (usdt_contract_address, _) = usdt_contract
        .deploy(@array![1000000000000000000000, 0, 'depositor'])
        .unwrap();

    return (escrow_contract_address, usdt_contract_address);
}
#[test]
fn test_setup() {
    let (contract_address, usdt_contract_address) = __setup__();

    println!("Deployed address: {:?}", contract_address);
    println!("Deploye USDT address: {:?}", usdt_contract_address);
}

#[test]
fn test_initialize_escrow() {
    let (contract_address, _) = __setup__();
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
fn test_fund_escrow() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Only depositor can fund.')]
fn test_only_depositor_can_fund_escrow() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();
    let other = OTHER();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == 250, Errors::INVALID_AMOUNT);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, other);

    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);
    stop_cheat_caller_address(contract_address);
}


#[test]
#[should_panic(expected: 'Amount is less than expected')]
fn test_can_not_fund_escrow_with_wrong_amount() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();
    let other = OTHER();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == 250, Errors::INVALID_AMOUNT);

    escrow_contract_dispatcher.fund_escrow(escrow_id, 200, usdt_contract_address);
    stop_cheat_caller_address(contract_address);
}


#[test]
fn test_fund_escrow_event_emission() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let mut spy = spy_events();

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    stop_cheat_caller_address(contract_address);

    // check events are emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    EscrowContract::Event::EscrowFunded(
                        EscrowContract::EscrowFunded {
                            depositor, amount, escrow_address: contract_address
                        }
                    )
                )
            ]
        );
}


#[test]
fn test_depositor_approve() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    assert(escrow_contract_dispatcher.get_balance() == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // approve funds to be released
    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.depositor_approve(escrow_id);
    stop_cheat_caller_address(contract_address);
}


#[test]
#[should_panic(expected: 'Unauthorized caller')]
fn test_depositor_approve_wrong_caller() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();
    let other = OTHER();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    IERC20Dispatcher { contract_address: usdt_contract_address }.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    assert(escrow_contract_dispatcher.get_balance() == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // approve funds to be released by wrong caller
    start_cheat_caller_address(contract_address, other);
    escrow_contract_dispatcher.depositor_approve(escrow_id);
    stop_cheat_caller_address(contract_address);
}


#[test]
#[should_panic(expected: 'Escrow does not exist')]
fn test_depositor_approve_non_existent_escrow() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // approve funds to be released for non-existent escrow
    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.depositor_approve(999); // Non-existent escrow ID
}


#[test]
#[should_panic(expected: 'Escrow is not funded')]
fn test_depositor_approve_without_funding() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // approve funds to be released without funding
    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.depositor_approve(escrow_id);
    stop_cheat_caller_address(contract_address);
}


#[test]
fn test_depositor_approve_event_emission() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let mut spy = spy_events();

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    assert(escrow_contract_dispatcher.get_balance() == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // approve funds to be released
    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.depositor_approve(escrow_id);

    // check events are emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    EscrowContract::Event::DepositorApproved(
                        EscrowContract::DepositorApproved {
                            depositor: depositor,
                            escrow_id: escrow_id,
                            time_of_approval: starknet::get_block_timestamp()
                        }
                    )
                )
            ]
        );
}


#[test]
fn test_release_funds() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();
    let arbiter = ARBITER();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    assert(escrow_contract_dispatcher.get_balance() == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // let depositor approve funds to be released
    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.depositor_approve(escrow_id);
    stop_cheat_caller_address(contract_address);

    // let arbiter approve funds to be released
    start_cheat_caller_address(contract_address, arbiter);
    escrow_contract_dispatcher.arbiter_approve(escrow_id);
    stop_cheat_caller_address(contract_address);

    // release funds to beneficiary
    start_cheat_caller_address(contract_address, benefeciary_address);
    escrow_contract_dispatcher.release_funds(escrow_id, usdt_contract_address);

    assert(erc20_dispatcher.balance_of(benefeciary_address) == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Depositor not approved')]
fn test_release_funds_without_depositor_approval() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();
    let arbiter = ARBITER();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    assert(escrow_contract_dispatcher.get_balance() == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // let arbiter approve funds to be released
    start_cheat_caller_address(contract_address, arbiter);
    escrow_contract_dispatcher.arbiter_approve(escrow_id);
    stop_cheat_caller_address(contract_address);

    // release funds to beneficiary
    start_cheat_caller_address(contract_address, benefeciary_address);
    escrow_contract_dispatcher.release_funds(escrow_id, usdt_contract_address);
}

#[test]
#[should_panic(expected: 'Arbiter not approved')]
fn test_release_funds_without_arbiter_approval() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    assert(escrow_contract_dispatcher.get_balance() == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // let depositor approve funds to be released
    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.depositor_approve(escrow_id);
    stop_cheat_caller_address(contract_address);

    // release funds to beneficiary
    start_cheat_caller_address(contract_address, benefeciary_address);
    escrow_contract_dispatcher.release_funds(escrow_id, usdt_contract_address);
}

#[test]
#[should_panic(expected: 'Escrow does not exist')]
fn test_release_funds_non_existent_escrow() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let escrow_id: u64 = 7;
    let fake_escrow_id: u64 = 999; // Non-existent escrow ID
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();
    let arbiter = ARBITER();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    assert(escrow_contract_dispatcher.get_balance() == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // let depositor approve funds to be released
    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.depositor_approve(escrow_id);
    stop_cheat_caller_address(contract_address);

    // let arbiter approve funds to be released
    start_cheat_caller_address(contract_address, arbiter);
    escrow_contract_dispatcher.arbiter_approve(escrow_id);
    stop_cheat_caller_address(contract_address);

    // release funds to beneficiary
    start_cheat_caller_address(contract_address, benefeciary_address);
    escrow_contract_dispatcher.release_funds(fake_escrow_id, usdt_contract_address);

    assert(erc20_dispatcher.balance_of(benefeciary_address) == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);
}


#[test]
fn test_release_funds_event_emission() {
    let (contract_address, usdt_contract_address) = __setup__();
    println!("Deployed address: {:?}", contract_address);

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: usdt_contract_address };

    let mut spy = spy_events();

    let escrow_id: u64 = 7;
    let benefeciary_address = BENEFICIARY();
    let provider_address = starknet::contract_address_const::<0x124>();
    let amount: u256 = 250;

    let depositor = DEPOSITOR();
    let arbiter = ARBITER();

    start_cheat_caller_address(contract_address, depositor);

    escrow_contract_dispatcher
        .initialize_escrow(escrow_id, benefeciary_address, provider_address, amount);

    let escrow_data = escrow_contract_dispatcher.get_escrow_details(7);

    assert(escrow_data.amount == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(usdt_contract_address, depositor);
    erc20_dispatcher.approve(contract_address, amount);
    stop_cheat_caller_address(usdt_contract_address);

    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.fund_escrow(escrow_id, amount, usdt_contract_address);

    assert(
        escrow_contract_dispatcher.is_escrow_funded(escrow_id) == true, Errors::ESCROW_NOT_FUNDED
    );

    assert(escrow_contract_dispatcher.get_balance() == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // let depositor approve funds to be released
    start_cheat_caller_address(contract_address, depositor);
    escrow_contract_dispatcher.depositor_approve(escrow_id);
    stop_cheat_caller_address(contract_address);

    // let arbiter approve funds to be released
    start_cheat_caller_address(contract_address, arbiter);
    escrow_contract_dispatcher.arbiter_approve(escrow_id);
    stop_cheat_caller_address(contract_address);

    // release funds to beneficiary
    start_cheat_caller_address(contract_address, benefeciary_address);
    escrow_contract_dispatcher.release_funds(escrow_id, usdt_contract_address);

    assert(erc20_dispatcher.balance_of(benefeciary_address) == amount, Errors::INVALID_AMOUNT);

    stop_cheat_caller_address(contract_address);

    // check events are emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    EscrowContract::Event::FundsReleased(
                        EscrowContract::FundsReleased {
                            escrow_id: escrow_id, beneficiary: benefeciary_address, amount,
                        }
                    )
                )
            ]
        );
}

#[test]
#[should_panic(expected: 'Invalid amount')]
fn test_initialize_zero_amount_should_fail() {
    let (contract_address, _) = __setup__();
    let escrow = IEscrowDispatcher { contract_address };
    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    escrow.initialize_escrow(2, BENEFICIARY(), contract_address_const::<0x999>(), 0);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Escrow ID already exists')]
fn test_initialize_twice_same_id_should_fail() {
    let (contract_address, _) = __setup__();

    let escrow = IEscrowDispatcher { contract_address };
    let depositor = DEPOSITOR();

    start_cheat_caller_address(contract_address, depositor);

    let escrow_id = 3;
    let provider = contract_address_const::<0x111>();

    // First call should succeed
    escrow.initialize_escrow(escrow_id, BENEFICIARY(), provider, 100);

    // Second call should fail
    let result = escrow.initialize_escrow(escrow_id, BENEFICIARY(), provider, 100);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'Unauthorized caller')]
fn test_initialize_wrong_caller_should_fail() {
    let (contract_address, _) = __setup__();
    let escrow = IEscrowDispatcher { contract_address };

    let wrong_caller = contract_address_const::<0xDEADBEEF>();
    start_cheat_caller_address(contract_address, wrong_caller);

    let result = escrow.initialize_escrow(4, BENEFICIARY(), contract_address_const::<0x888>(), 100);

    stop_cheat_caller_address(contract_address);
}

