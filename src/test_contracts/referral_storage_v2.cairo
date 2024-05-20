use starknet::{ContractAddress,ClassHash};
use zeroable::Zeroable;


#[starknet::interface]
trait IReferralStorageV2<TContractState> {
    fn get_trader_referral_code(
        ref self: TContractState,
        _account: ContractAddress,
    ) -> felt252;

    fn get_code_owner(
        ref self: TContractState,
        _code: felt252,
    ) -> ContractAddress;

    fn get_code_from_owner(
        ref self: TContractState,
        _account: ContractAddress,
    ) -> felt252;

    fn set_trader_referral_code(
        ref self: TContractState,
        _code: felt252,
    );

    fn register_code(
        ref self: TContractState,
        _code: felt252,
    );

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

}


#[starknet::contract]
mod ReferralStorageV2 {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use starknet::ClassHash;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;


    component!(path: UpgradeableComponent, storage: upgradeable_storage, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SetTraderReferralCode: SetTraderReferralCode,
        RegisterCode: RegisterCode,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }


    #[derive(Drop, starknet::Event)]
    struct SetTraderReferralCode {
        account: ContractAddress,
        code: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct RegisterCode {
        code: felt252,
        account: ContractAddress,
    }

    #[storage]
    struct Storage {
        code_owner: LegacyMap::<felt252, ContractAddress>,
        owner_to_code: LegacyMap::<ContractAddress, felt252>,
        trader_referral_codes: LegacyMap::<ContractAddress, felt252>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable_storage: UpgradeableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ReferralStorageV2 of super::IReferralStorageV2<ContractState> {

        fn get_trader_referral_code(
            ref self: ContractState,
            _account: ContractAddress,
        ) -> felt252 {
             self.trader_referral_codes.read(_account)
        }

        fn get_code_owner(
            ref self: ContractState,
            _code: felt252,
        ) -> ContractAddress {
            self.code_owner.read(_code)
        }

        fn get_code_from_owner(
            ref self: ContractState,
            _account: ContractAddress,
        ) -> felt252 {
            self.owner_to_code.read(_account)
        }

        fn set_trader_referral_code(
            ref self: ContractState,
            _code: felt252,
        ){
            assert!(self.code_owner.read(_code).is_non_zero(), "ReferralStorage: code not found");
            assert!(self.code_owner.read(_code) != get_caller_address(), "ReferralStorage: code owner cannot set code for himself");

            let _account = get_caller_address();
            self.trader_referral_codes.write(_account, _code);
            self.emit(SetTraderReferralCode{account:_account, code: _code});  
        }

        fn register_code(
            ref self: ContractState,
            _code: felt252,
        ){
            assert!(self.owner_to_code.read(get_caller_address()).is_non_zero(), "ReferralStorage: user already has a code");

            assert!(!self.code_owner.read(_code).is_non_zero(), "ReferralStorage: code already registered");

            self.code_owner.write(_code, get_caller_address());
            self.owner_to_code.write(get_caller_address(), _code);

            self.emit(RegisterCode{code:_code, account: get_caller_address()});
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();

            self.upgradeable_storage._upgrade(new_class_hash);
        }
    }



}

