use poseidon::poseidon_hash_span;
use starknet::ContractAddress;

fn get_token_key(
    name_: felt252,
    symbol_: felt252,
    decimals_: u8,
    initial_supply: u256,
    recipient: ContractAddress,
    token_length: u64
) -> felt252 {
    let mut data = array![];
    data.append(name_.into());
    data.append(symbol_.into());
    data.append(decimals_.into());
    data.append(token_length.into());
    poseidon_hash_span(data.span())
}
