use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn totalSupply(self: @TContractState) -> u256;
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;

    // returns true if the call succeeded: for transfer, transfer_from and approve
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn increaseAllowance(
        ref self: TContractState, spender: ContractAddress, added_value: u256
    ) -> bool;
    fn decreaseAllowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: u256
    ) -> bool;
    fn get_factory(self: @TContractState) -> ContractAddress;
    fn initialize(
        ref self: TContractState,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        initial_supply: u256,
        recipient: ContractAddress
    );
}


#[starknet::contract]
mod SampleTokenForFactory {
    use openzeppelin::token::erc20::erc20::ERC20Component::HasComponent;
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        factory: ContractAddress,
        decimals: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    // #[constructor]
    // fn constructor(ref self: ContractState, initial_supply: u256, recipient: ContractAddress) {
    //     let name = 'MyToken';
    //     let symbol = 'MTK';

    //     self.erc20.initializer(name, symbol);
    //     self.erc20._mint(recipient, initial_supply);
    // }
    #[constructor]
    fn constructor(ref self: ContractState,) {
        self.factory.write(get_caller_address());
    }
    fn get_factory(self: @ContractState) -> ContractAddress {
        self.factory.read()
    }

    fn initialize(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        assert(get_caller_address() == self.factory.read(), 'Should be called from factory');
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);

        self.decimals.write(decimals);
        // self.total_supply.write(initial_supply);
        self.erc20._mint(recipient, initial_supply);
    // self.balances.write(recipient, initial_supply);
    // self
    //     .erc20
    //     .emit(
    //         Event::ERC20Event::Transfer(
    //             Transfer {
    //                 from: contract_address_const::<0>(), to: recipient, value: initial_supply
    //             }
    //         )
    //     )
    // self
    //     .emit(
    //         Event::Transfer(
    //             Transfer {
    //                 from: contract_address_const::<0>(), to: recipient, value: initial_supply
    //             }
    //         )
    //     );
    }
}
