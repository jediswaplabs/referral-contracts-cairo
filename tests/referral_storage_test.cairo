use starknet::{ContractAddress,get_caller_address,contract_address_try_from_felt252};
use zeroable::Zeroable;
use jediswap_referral::referral_storage::{ReferralStorage,IReferralStorageDispatcher,IReferralStorageDispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, spy_events,
    SpyOn, EventSpy, EventFetcher, Event, EventAssertions
};
use jediswap_referral::test_contracts::referral_storage_v2::{ReferralStorageV2,IReferralStorageV2Dispatcher,IReferralStorageV2DispatcherTrait};
use openzeppelin::upgrades::upgradeable::UpgradeableComponent;


fn setup_referral_storage_dispatcher() -> (ContractAddress,IReferralStorageDispatcher,ContractAddress) {
    let contract = declare("ReferralStorage");

    let mut contract_constructor_calldata = Default::default();
    let owner = contract_address_try_from_felt252('owner').unwrap();

    Serde::serialize(@owner, ref contract_constructor_calldata);
    let contract_address = contract.deploy(@contract_constructor_calldata).unwrap();

    (contract_address,IReferralStorageDispatcher { contract_address },owner)
}

#[test]
fn test_set_referrer() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();

    let user2 = 124.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user2);
    dispatcher.set_referrer(user);

    let user2_referral_code = dispatcher.get_referrer(user2);
    assert_eq!(user2_referral_code, user);
}

#[test]
#[should_panic(expected: ("ReferralStorage: referrer cannot refer themselves",))]
fn test_set_referrer_self() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user);
    dispatcher.set_referrer(user);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_upgrade_referral_storage_by_not_onwer() {
    let (_contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let new_storage_class_hash = declare("ReferralStorageV2").class_hash;
    dispatcher.upgrade(new_storage_class_hash);
}

#[test]
fn test_upgrade_referral_storage() {
    let (contract_address,dispatcher,owner) = setup_referral_storage_dispatcher();
    
    let new_storage_class_hash = declare("ReferralStorageV2").class_hash;
    let mut spy = spy_events(SpyOn::One(contract_address));
    start_prank(CheatTarget::One(contract_address), owner);
    dispatcher.upgrade(new_storage_class_hash);


    spy.assert_emitted(
        @array![
            (
                contract_address,
                UpgradeableComponent::Event::Upgraded(
                    UpgradeableComponent::Upgraded { class_hash: new_storage_class_hash }
                )
            )
        ]
    );
}
