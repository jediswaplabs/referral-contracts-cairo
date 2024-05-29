use starknet::{ContractAddress,ClassHash};
use zeroable::Zeroable;


#[starknet::interface]
trait IReferralStorageV2<TContractState> {
    fn get_referrer(
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

    fn set_referrer(
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
        SetReferrer: SetReferrer,
        RegisterCode: RegisterCode,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }


    #[derive(Drop, starknet::Event)]
    struct SetReferrer {
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
        referrers: LegacyMap::<ContractAddress, felt252>,
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

        fn get_referrer(
            ref self: ContractState,
            _account: ContractAddress,
        ) -> felt252 {
             self.referrers.read(_account)
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

        fn set_referrer(
            ref self: ContractState,
            _code: felt252,
        ){
            assert!(self.code_owner.read(_code).is_non_zero(), "ReferralStorage: code not found");
            assert!(self.code_owner.read(_code) != get_caller_address(), "ReferralStorage: referrer cannot refer himself");

            let _account = get_caller_address();
            self.referrers.write(_account, _code);
            self.emit(SetReferrer{account:_account, code: _code});  
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

