// Ampliació del contracte de Crowdfunding
// 
// 
//  

#![no_std]

use multiversx_sc::derive_imports::*;
#[allow(unused_imports)]
use multiversx_sc::imports::*;

#[type_abi]
#[derive(TopEncode, TopDecode, PartialEq, Clone, Copy)]
pub enum Status {
    FundingPeriod,
    Successful,
    Failed,
}

/// An empty contract. To be used as a template when starting a new contract from scratch.
#[multiversx_sc::contract]
pub trait CrowdfundingSc {
    #[init]
    fn init(&self, target: BigUint, deadline: u64) {
        require!(target > 0, "Target must be more than 0");
        self.target().set(target);

        require!(
            deadline > self.get_current_time(),
            "Deadline can't be in the past"
        );
        self.deadline().set(deadline);
  
    }

    #[upgrade]
    fn upgrade(&self) {}

    // Endpoints

    #[endpoint]
    #[payable("EGLD")]
    fn fund(&self) {
        let payment = self.call_value().egld().clone_value();

        let current_time = self.blockchain().get_block_timestamp();
        require!(
            current_time < self.deadline().get(),
            "cannot fund after deadline"
        );

        let caller = self.blockchain().get_caller();
        let deposited_amount = self.deposit(&caller).get();
        let caller_amount = deposited_amount + payment.clone();
        require!(
            self.validate_donation(payment.clone(),  caller_amount.clone()),
            "deposited fund not match limits"
            );
        require!(
            self.validate_max_donations(payment.clone()),
            "total donations exceed maximum target"
        );
        self.deposit(&caller).set(caller_amount);
    }

    #[endpoint]
    fn claim(&self) {
        match self.status() {
            Status::FundingPeriod => sc_panic!("cannot claim before deadline"),
            Status::Successful => {
                let caller = self.blockchain().get_caller();
                require!(
                    caller == self.blockchain().get_owner_address(),
                    "only owner can claim successful funding"
                );

                let sc_balance = self.get_current_funds();
                self.send().direct_egld(&caller, &sc_balance);
            }
            Status::Failed => {
                let caller = self.blockchain().get_caller();
                let deposit = self.deposit(&caller).get();

                if deposit > 0u32 {
                    self.deposit(&caller).clear();
                    self.send().direct_egld(&caller, &deposit);
                }
            }
        }
    }

        

    // Establir quantitat màxima objectiu (només propietari)
    #[only_owner]
    #[endpoint(SetMaxTarget)]
    fn set_max_target(&self, maxtarget: BigUint)
    {
        require!(maxtarget > 0u32, "Maximum target must be more than 0");
        self.maxtarget().set(maxtarget);
    }

    // Establir límit màxim donatius per donant (només propietari)
    #[only_owner]
    #[endpoint(SetMaxFunds)]
    fn set_max_funds(&self, maxfund: BigUint)
    {
        require!(maxfund > 0u32, "Maximum fund must be more than 0");
        self.maxfund().set(maxfund);
    }
    
    // Establir límit màxim donatiu per donació (només propietari)
    #[only_owner]
    #[endpoint(SetLimitFunds)]
    fn set_limit_funds(&self, limitfund: BigUint)
    {
        require!(limitfund > 0u32, "Limit fund must be more than 0");
        self.limitfund().set(limitfund);
    }
    
    // Views
    
    #[view]
    fn status(&self) -> Status {
        if self.get_current_time() <= self.deadline().get() {
            Status::FundingPeriod
        } else if self.get_current_funds() >= self.target().get() {
            Status::Successful
        } else {
            Status::Failed
        }
    }

    #[view(getCurrentFunds)]
    fn get_current_funds(&self) -> BigUint {
        self.blockchain()
            .get_sc_balance(&EgldOrEsdtTokenIdentifier::egld(), 0)
    }


    // private

    fn get_current_time(&self) -> u64 {
        self.blockchain().get_block_timestamp()
    }

    fn validate_donation(&self, payment: BigUint, deposited_amount: BigUint) -> bool 
    {
        // Validar donatiu:
        // 1. payment inferior a limitfund si s'ha establert
        // 2. Acumulat donant inferior a la donació màxima per donant si s'ha establert
        // Paràmetres i variables:
        // 1. payment és la donació que fa el donant
        // 2. deposited_amount és la quantitat recuperada del caller que en aquest cas 
        //    és el wallet del donant

        let mut valid = true;
        
        if (self.limitfund().get() > 0u32) && (payment > self.limitfund().get())
         {
            valid = false;
         }
        if valid && (self.maxfund().get() > 0u32) && (deposited_amount > self.maxfund().get())
         {
            valid = false;
         }
        if valid && (self.get_current_funds() + payment > self.maxtarget().get())
         {
            valid = false;
         }
        valid
    }
      
    fn validate_max_donations(&self, payment: BigUint) -> bool 
    {
        // Validar límit màxim donatius
        // 1. Total acumulat de donacions inferior a la quantitat màxima objectiu si s'ha establert
        // Paràmetres i variables:
        // 1. payment és la donació que fa el donant
        
        self.get_current_funds() + payment < self.maxtarget().get()
        
    }
    
    // storage
    // target = objectiu del crowdfunding
    #[view(getTarget)]
    #[storage_mapper("target")]
    fn target(&self) -> SingleValueMapper<BigUint>;

    // maxtarget = objectiu màxim del crowdfunding
    #[view(getMaxTarget)]
    #[storage_mapper("maxtarget")]
    fn maxtarget(&self) -> SingleValueMapper<BigUint>;

    // deadline = data de finalització del crowdfunding
    #[view(getDeadline)]
    #[storage_mapper("deadline")]
    fn deadline(&self) -> SingleValueMapper<u64>;

    // deposit = depòsit acumulat de donacions
    #[view(getDeposit)]
    #[storage_mapper("deposit")]
    fn deposit(&self, donor: &ManagedAddress) -> SingleValueMapper<BigUint>;

    // maxfund = límit màxim de donatius d'un mateix donant
    #[view(getMaxFund)]
    #[storage_mapper("maxfund")]
    fn maxfund(&self) -> SingleValueMapper<BigUint>;

    // limitfund = límit per donació
    #[view(getLimitFund)]
    #[storage_mapper("limitfund")]
    fn limitfund(&self) -> SingleValueMapper<BigUint>;
    
}
