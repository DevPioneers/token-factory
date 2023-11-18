use starknet::{ContractAddress};
use starknet::class_hash::ClassHash;

#[starknet::interface]
trait IFactory<TContractState> {
    fn create_token(
        ref self: TContractState,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        initial_supply: u256,
        recipient: ContractAddress
    ) -> ContractAddress;
    fn get_token_length(self: @TContractState) -> u64;
    fn get_token_by_index(self: @TContractState, index: u64) -> ContractAddress;
}

#[starknet::contract]
mod Factory {
    use core::option::OptionTrait;
    use array::{ArrayTrait, SpanTrait};
    use hash::LegacyHash;
    use serde::Serde;
    use starknet::class_hash::ClassHash;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use starknet::syscalls::deploy_syscall;
    use traits::Into;
    use zeroable::Zeroable;
    use factory_token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use factory_token::utils::get_token_key;

    #[storage]
    struct Storage {
        token_class_hash: ClassHash,
        owner: ContractAddress,
        token_length: u64,
        token_by_index: LegacyMap::<u64, ContractAddress>,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TokenCreated: TokenCreated
    }

    #[derive(Drop, starknet::Event)]
    struct TokenCreated {
        #[key]
        name: felt252,
        #[key]
        symbol: felt252,
        #[key]
        decimals: u8,
        #[key]
        initial_supply: u256,
        #[key]
        owner: ContractAddress,
        token: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, token_contract_class_hash: ClassHash, owner: ContractAddress
    ) {
        self.token_class_hash.write(token_contract_class_hash);
        self.owner.write(owner);
        self.token_length.write(0);
    }

    #[external(v0)]
    impl FactoryImpl of super::IFactory<ContractState> {
        fn create_token(
            ref self: ContractState,
            name: felt252,
            symbol: felt252,
            decimals: u8,
            initial_supply: u256,
            recipient: ContractAddress
        ) -> ContractAddress {
            let class_hash = self.token_class_hash.read();
            // arguments for pool deoloyment
            let contract_address_salt = LegacyHash::hash(get_contract_address().into(), recipient);
            let mut data = array![];
            data.append(name);
            data.append(symbol);
            data.append(decimals.into());
            data.append(initial_supply.try_into().unwrap());
            data.append(recipient.into());
            let calldata = data.span();
            let deploy_from_zero = false;

            // deoloy pool contract
            let (created_token, returned_data) = deploy_syscall(
                class_hash, contract_address_salt, calldata, deploy_from_zero: false,
            )
                .unwrap();
            // IERC20Dispatcher { contract_address: created_token }.initialize(token0, token1);
            let current_index: u64 = self.token_length.read();
            self.token_by_index.write(current_index + 1, created_token);
            self.token_length.write(current_index + 1);
            self
                .emit(
                    Event::TokenCreated(
                        TokenCreated {
                            name,
                            symbol,
                            decimals,
                            initial_supply,
                            owner: recipient,
                            token: created_token
                        }
                    )
                );
            created_token
        }
        fn get_token_length(self: @ContractState) -> u64 {
            self.token_length.read()
        }
        fn get_token_by_index(self: @ContractState, index: u64) -> ContractAddress {
            let current_index = self.token_length.read();
            assert(index <= current_index, 'invalid token index');
            self.token_by_index.read(index)
        }
    }
}
