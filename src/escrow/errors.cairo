pub mod Errors {
    pub const ESCROW_NOT_FOUND: felt252 = 'Escrow does not exist';
    pub const INVALID_BENEFICIARY_ADDRESS: felt252 = 'Invalid beneficiary address';
    pub const INVALID_PROVIDER_ADDRESS: felt252 = 'Invalid provider address';
    pub const UNAUTHORIZED_CALLER: felt252 = 'Unauthorized caller';
    pub const ESCROW_ID_ALREADY_EXISTS: felt252 = 'Escrow ID already exists';
    pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
    pub const INVALID_ADDRESSES: felt252 = 'Provider cannot be beneficiary';
    pub const ALREADY_APPROVED: felt252 = 'Already approved';
    pub const TIMER_NOT_EXPIRED: felt252 = 'timer not expired';
    pub const ARBITER_NOT_APPROVED: felt252 = 'Arbiter not approved';
    pub const DEPOSITOR_NOT_APPROVED: felt252 = 'Depositor not approved';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient Balance';
    pub const ESCROW_NOT_FUNDED: felt252 = 'Escrow is not funded';
}
