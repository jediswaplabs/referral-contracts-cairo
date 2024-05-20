use starknet::{ContractAddress,ClassHash};
use zeroable::Zeroable;


#[starknet::interface]
trait IReferralStorage<TContractState> {
    fn get_trader_referral_code(
         self: @TContractState,
        _account: ContractAddress,
    ) -> ContractAddress;

    fn set_trader_referral_code(
        ref self: TContractState,
        _code: ContractAddress,
    );

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}


#[starknet::contract]
mod ReferralStorage {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use starknet::ClassHash;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;


    component!(path: UpgradeableComponent, storage: upgradeable_storage, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    /// Ownable
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SetTraderReferralCode: SetTraderReferralCode,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }


    #[derive(Drop, starknet::Event)]
    struct SetTraderReferralCode {
        account: ContractAddress,
        code: ContractAddress,
    }

    #[storage]
    struct Storage {
        // @notice Maps the trader to the referee code
        trader_referral_codes: LegacyMap::<ContractAddress, ContractAddress>,
        
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable_storage: UpgradeableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl ReferralStorage of super::IReferralStorage<ContractState> {

        fn get_trader_referral_code(
             self: @ContractState,
            _account: ContractAddress,
        ) -> ContractAddress {
             self.trader_referral_codes.read(_account)
        }

        // @notice Sets the code to be referred by the trader
        // @param _code The code to set
        // @dev Trader can set the code only once
        // @dev Code owner cannot set the code for himself
        fn set_trader_referral_code(
            ref self: ContractState,
            _code: ContractAddress,
        ){
            assert!(_code != get_caller_address(), "ReferralStorage: code owner cannot set code for himself");

            if(!self.trader_referral_codes.read(get_caller_address()).is_non_zero()){
                let _account = get_caller_address();
                self.trader_referral_codes.write(_account, _code);
                self.emit(SetTraderReferralCode{account:_account, code: _code});              
            }
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();

            self.upgradeable_storage._upgrade(new_class_hash);
        }
    }
}

