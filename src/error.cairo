#[derive(Drop, Copy, starknet::Store, Serde)]
mod Error {
    const OnlyOwner: felt252 = 'only_owner';
}
