use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Escrow {
    pub client_address: ContractAddress,
    pub provider_address: ContractAddress,
    pub amount: u256,
    pub balance: u256
}
