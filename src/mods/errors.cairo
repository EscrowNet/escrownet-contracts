pub mod Errors {
    pub const ESCROW_NOT_FOUND: felt252 = 'Escrow does not exist';
    pub const INVALID_BENEFICIARY_ADDRESS: felt252 = 'Invalid beneficiary address';
    pub const INVALID_PROVIDER_ADDRESS: felt252 = 'Invalid provider address';
    pub const UNAUTHORIZED_CALLER: felt252 = 'Unauthorized caller';
    pub const ESCROW_ID_ALREADY_EXISTS: felt252 = 'Escrow ID already exists';
    pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
    pub const INVALID_ADDRESSES: felt252 = 'Provider cannot be beneficiary';
    
}
