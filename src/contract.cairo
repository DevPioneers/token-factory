use starknet::{ContractAddress};
use starknet::class_hash::ClassHash;
use starknet::SyscallResultTrait;

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
    fn get_token_length(self: @TContractState) -> u256;
    fn get_token_by_index(self: @TContractState, index: u256) -> ContractAddress;
    fn get_fee_token(self: @TContractState) -> ContractAddress;
    fn get_fee_amount(self: @TContractState) -> u256;
    fn set_fee_token(ref self: TContractState, fee_token: ContractAddress);
    fn set_fee_amount(ref self: TContractState, fee_amount: u256);
    fn set_fee_receiver(ref self: TContractState, fee_receiver: ContractAddress);
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
    use factory_token::error::Error;
    #[storage]
    struct Storage {
        token_class_hash: ClassHash,
        owner: ContractAddress,
        token_length: u256,
        fee_token: ContractAddress,
        fee_amount: u256,
        fee_receiver: ContractAddress,
        token_by_index: LegacyMap::<u256, ContractAddress>,
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
        ref self: ContractState,
        token_contract_class_hash: ClassHash,
        owner: ContractAddress,
        fee_token: ContractAddress,
        fee_amount: u256
    ) {
        self.token_class_hash.write(token_contract_class_hash);
        self.owner.write(owner);
        self.fee_receiver.write(owner);
        self.fee_token.write(fee_token);
        self.fee_amount.write(fee_amount);
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
            // arguments for token deoloyment
            let contract_address_salt = LegacyHash::hash(
                recipient.into(),
                keccak::keccak_u256s_le_inputs(array![self.token_length.read()].span())
            );

            let calldata = ArrayTrait::<felt252>::new().span();

            // deoloy erc20 contract
            let (created_token, _) = deploy_syscall(
                class_hash, contract_address_salt, calldata, false,
            )
                .unwrap();
            IERC20Dispatcher { contract_address: created_token }
                .initialize(name, symbol, decimals, initial_supply, recipient);
            let current_index: u256 = self.token_length.read();
            self.token_by_index.write(current_index + 1, created_token);
            self.token_length.write(current_index + 1);
            let fee_token_dispatcher = IERC20Dispatcher { contract_address: self.fee_token.read() };
            fee_token_dispatcher
                .transferFrom(get_caller_address(), self.owner.read(), self.fee_amount.read());

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
        fn get_token_length(self: @ContractState) -> u256 {
            self.token_length.read()
        }
        fn get_token_by_index(self: @ContractState, index: u256) -> ContractAddress {
            let current_index = self.token_length.read();
            assert(index <= current_index, 'invalid token index');
            self.token_by_index.read(index)
        }
        fn set_fee_token(ref self: ContractState, fee_token: ContractAddress) {
            self.only_owner();
            self.fee_token.write(fee_token);
        }
        fn set_fee_receiver(ref self: ContractState, fee_receiver: ContractAddress) {
            self.only_owner();
            self.fee_receiver.write(fee_receiver);
        }

        fn set_fee_amount(ref self: ContractState, fee_amount: u256) {
            self.only_owner();
            self.fee_amount.write(fee_amount);
        }
        fn get_fee_token(self: @ContractState) -> ContractAddress {
            self.fee_token.read()
        }
        fn get_fee_amount(self: @ContractState) -> u256 {
            self.fee_amount.read()
        }
    }
    // *************************************************************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn only_owner(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), Error::OnlyOwner);
        }
    }
}

