#[starknet::interface]
pub trait IEscrownet<TContractState> {}


#[starknet::contract]
pub mod Escrownet {
    use super::{IEscrownet};
    use escrownet_contract::escrow::escrow_factory::EscrowFactory;

    // components
    component!(path: EscrowFactory, storage: factory_storage, event: EscrowFactoryEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EscrowFactoryEvent: EscrowFactory::Event
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        factory_storage: EscrowFactory::Storage,
    }


    #[abi(embed_v0)]
    impl FactoryImpl = EscrowFactory::Escrows<ContractState>;


    #[abi(embed_v0)]
    impl EscrownetImpl of IEscrownet<ContractState> {}
}
