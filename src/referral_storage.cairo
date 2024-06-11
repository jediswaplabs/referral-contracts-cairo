use starknet::{ContractAddress,ClassHash};
use zeroable::Zeroable;


#[starknet::interface]
trait IReferralStorage<TContractState> {
    fn get_referrer(
        self: @TContractState,
        account: ContractAddress,
    ) -> ContractAddress;

    fn set_referrer(
        ref self: TContractState,
        address: ContractAddress,
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
        SetReferrer: SetReferrer,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }


    #[derive(Drop, starknet::Event)]
    struct SetReferrer {
        account: ContractAddress,
        referrer: ContractAddress,
    }

    #[storage]
    struct Storage {
        // @notice Maps the referee to the referrer
        referrers: LegacyMap::<ContractAddress, ContractAddress>,
        
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

        fn get_referrer(
            self: @ContractState,
            account: ContractAddress,
        ) -> ContractAddress {
             self.referrers.read(account)
        }

        // @notice Sets the referrer to be referred by the caller
        // @param address The referrer to set
        // @dev An address can set the referrer only once
        // @dev referrer cannot set refer themselves
        fn set_referrer(
            ref self: ContractState,
            address: ContractAddress,
        ){
            assert!(address != get_caller_address(), "ReferralStorage: referrer cannot refer themselves");

            if(!self.referrers.read(get_caller_address()).is_non_zero()){
                let account = get_caller_address();
                self.referrers.write(account, address);
                self.emit(SetReferrer{account:account, referrer: address});              
            }
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();

            self.upgradeable_storage._upgrade(new_class_hash);
        }
    }
}

