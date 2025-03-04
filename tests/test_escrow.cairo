use escrownet_contract::mods::escrow::escrow_factory::IEscrowFactoryDispatcherTrait;
use escrownet_contract::mods::interface::iescrow::IEscrowDispatcherTrait;
use starknet::ContractAddress;

use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp, spy_events,
    EventSpyAssertionsTrait,
};
use escrownet_contract::mods::interface::iescrow::{IEscrowDispatcher};
use escrownet_contract::mods::errors::Errors;
use escrownet_contract::mods::escrow::escrow_factory::EscrowFactory;
use escrownet_contract::mods::escrow::escrow_factory::{IEscrowFactoryDispatcher};


fn BENEFICIARY() -> ContractAddress {
    'benefeciary'.try_into().unwrap()
}

fn DEPOSITOR() -> ContractAddress {
    'depositor'.try_into().unwrap()
}

fn ARBITER() -> ContractAddress {
    'arbiter'.try_into().unwrap()
}

fn TOKEN() -> ContractAddress {
    'token'.try_into().unwrap()
}

const SALT: felt252 = 'salt';

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

    let escrow_contract_dispatcher = IEscrowDispatcher { contract_address };
    let mut _spy = spy_events();

    // setup test data
    let escrow_id: u64 = 7;
    let benefeciary_address = starknet::contract_address_const::<0x123>();
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



//  #[test]
//  fn test_fund_funds() {
//      let contract_address = __setup__();
//     //  let escrow_factory_contract = IEscrowFactoryDispatcher { contract_address };
//     //  let escrows = escrow_factory_contract.get_escrow_contracts();
//      let escrow_contract_dispatcher = IEscrowDispatcher { contract_address: contract_address };
    

//      // Test data
//      let beneficiary_address = escrow_contract_dispatcher.get_beneficiary();
//      let provider_address = escrow_contract_dispatcher.get_provider_address();
//      let amount: u256 = 250;
//      let token_address = escrow_contract_dispatcher.token_address();
//      let depositor = escrow_contract_dispatcher.get_depositor();
//      let arbiter = escrow_contract_dispatcher.get_arbiter();
//      let salt = SALT;

//      // Deploy the escrow contract
//      start_cheat_caller_address(contract_address, beneficiary_address);
//      let escrow_factory = IEscrowFactoryDispatcher { contract_address };
//      escrow_factory.deploy_escrow(beneficiary_address, depositor, arbiter, salt);
//      let escrow_id = escrow_factory.get_escrow_id();
//      escrow_contract_dispatcher.get_escrow_exists(escrow_id);
//      stop_cheat_caller_address(contract_address);

//      // Retrieve the deployed escrow address
    
//      // Assuming the first entry is the new escrow

//       //Proceed with initializing and funding the escrow
//      start_cheat_caller_address(contract_address, depositor);
//      escrow_contract_dispatcher.initialize_escrow(escrow_id, beneficiary_address, provider_address, amount);
//       let escrow_data = escrow_contract_dispatcher.get_escrow_details(escrow_id);
//      stop_cheat_caller_address(contract_address);

//      start_cheat_caller_address(contract_address, depositor);
//      escrow_contract_dispatcher.fund_escrow(7, amount, token_address);
//      stop_cheat_caller_address(contract_address);
//  }

