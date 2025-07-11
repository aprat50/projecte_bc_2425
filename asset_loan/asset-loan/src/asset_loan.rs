#![no_std]

multiversx_sc::imports!();
multiversx_sc::derive_imports!();

// Status of the asset
#[type_abi]
#[derive(TopEncode, TopDecode, NestedEncode, NestedDecode, PartialEq)]
pub enum Status {
    Available,
    Cancel,
    Loan,
    Repair,
}

// Asset struct
#[type_abi]
#[derive(TopEncode, TopDecode, NestedEncode, NestedDecode)]
pub struct Asset<M: ManagedTypeApi> {
    code: ManagedBuffer<M>,
    name: ManagedBuffer<M>,
    location: ManagedBuffer<M>,
    status: Status,
    owner: ManagedAddress<M>,
    borrower: Option<ManagedAddress<M>>,
    loan_end_timestamp: Option<u64>,
}

#[multiversx_sc::contract]
pub trait AssetLoan {
    // Initialize the contract with the initial whitelist of authorized addresses and admin addresses
    #[allow_multiple_var_args]
    #[init]
    fn init(&self, initial_whitelist: MultiValueEncoded<ManagedAddress>, initial_admins: MultiValueEncoded<ManagedAddress>) {
        // Initialize whitelist with provided addresses
        let mut whitelist = self.whitelisted_addresses();
        for address in initial_whitelist {
            whitelist.insert(address);
        }
        // Initialize admin whitelist with provided addresses
        let mut admin_whitelist = self.admin_whitelist();
        for admin in initial_admins {
            admin_whitelist.insert(admin);
        }
    }
    
    #[allow_multiple_var_args]
    #[upgrade]
    fn upgrade(&self, new_admins: MultiValueEncoded<ManagedAddress>) {
        
        // Clear and re-initialize admin whitelist
        self.admin_whitelist().clear();
        let mut admin_whitelist = self.admin_whitelist();
        for admin in new_admins {
            admin_whitelist.insert(admin);
        }
    }

    // Endpoints

    // Whitelist endpoints

    #[endpoint(addToWhitelist)]
    fn add_to_whitelist(&self, address: ManagedAddress) {
        require!(self.authorized(), "Caller is not an admin");
        self.whitelisted_addresses().insert(address);
    }

    #[endpoint(removeFromWhitelist)]
    fn remove_from_whitelist(&self, address: ManagedAddress) {
        require!(self.authorized(), "Caller is not an admin");
        self.whitelisted_addresses().swap_remove(&address);
    }

    #[view(isWhitelisted)]
    fn is_whitelisted(&self, address: &ManagedAddress) -> bool {
        self.whitelisted_addresses().contains(address)
    }

    // Admin authorization check
    fn authorized(&self) -> bool {
        let caller = self.blockchain().get_caller();
        self.admin_whitelist().contains(&caller)
    }

    #[endpoint(registerAsset)]
    fn register_asset(
        &self,
        code: ManagedBuffer,
        name: ManagedBuffer,
        location: ManagedBuffer,
    ) {
        let caller = self.blockchain().get_caller();
        require!(self.asset(&code).is_empty(), "Asset already registered");

        require!(self.authorized(), "Caller is not an admin");

        let asset = Asset {
            code: code.clone(),
            name,
            location,
            status: Status::Available,
            owner: caller.clone(),
            borrower: None,
            loan_end_timestamp: None,
        };

        // Store the asset
        self.asset(&code).set(asset);
        
        // Add the asset code to owner's assets list
        self.owner_assets(&caller).insert(code);
    }
    
    #[endpoint(changeAssetStatus)]
    fn change_asset_status(&self, code: ManagedBuffer, new_status: Status) {
        // Get the asset
        require!(!self.asset(&code).is_empty(), "Asset not found");
        let mut asset = self.asset(&code).get();
        
        require!(self.authorized(), "Caller is not an admin");

        // Update the status
        asset.status = new_status;
        
        // Save the updated asset
        self.asset(&code).set(asset);
    }

    // Loan endpoints
    #[endpoint(registerLoan)]
    fn register_loan(
        &self,
        asset_code: ManagedBuffer,
        duration: u64,
    ) {
        require!(!self.asset(&asset_code).is_empty(), "Asset not found");
        let mut asset = self.asset(&asset_code).get();
        require!(asset.status == Status::Available, "Asset is not available for loan");
        
        let caller = self.blockchain().get_caller();
        require!(
            self.is_whitelisted(&caller),
            "Only whitelisted addresses can view their assets"
        );
        let current_timestamp = self.blockchain().get_block_timestamp();
        
        // Update asset
        asset.status = Status::Loan;
        asset.borrower = Some(caller);
        asset.loan_end_timestamp = Some(current_timestamp + duration);
        
        self.asset(&asset_code).set(asset);
    }

    #[endpoint(returnAsset)]
    fn return_asset(&self, asset_code: ManagedBuffer) {
        
        require!(!self.asset(&asset_code).is_empty(), "Asset not found");
        let caller = self.blockchain().get_caller();
        let mut asset = self.asset(&asset_code).get();
        
        require!(
            asset.borrower.clone().unwrap_or_else(|| sc_panic!("No borrower")) == caller,
            "Only the borrower can return the asset"
        );
        require!(asset.status == Status::Loan, "Asset is not on loan");
        
        // Update asset status
        asset.status = Status::Available;
        asset.borrower = None;
        asset.loan_end_timestamp = None;
        
        self.asset(&asset_code).set(asset);
    }

    
    #[view(getWhitelist)]
    fn get_whitelist(&self) -> MultiValueEncoded<ManagedAddress> {
        self.whitelisted_addresses().iter().collect()
    }
    
    #[view(getAdminWhitelist)]
    fn get_admin_whitelist(&self) -> MultiValueEncoded<ManagedAddress> {
        
        self.admin_whitelist().iter().collect()
    }

    #[endpoint(addToAdminWhitelist)]
    fn add_to_admin_whitelist(&self, address: ManagedAddress) {
        require!(self.authorized(), "Caller is not an admin");
        self.admin_whitelist().insert(address);
    }

    #[endpoint(removeFromAdminWhitelist)]
    fn remove_from_admin_whitelist(&self, address: ManagedAddress) {
        require!(self.authorized(), "Caller is not an admin");
        self.admin_whitelist().swap_remove(&address);
    }


    // Storage  
    #[view(getAsset)]
    #[storage_mapper("asset")]
    fn asset(&self, code: &ManagedBuffer) -> SingleValueMapper<Asset<Self::Api>>;

    #[view(getOwnerAssets)]
    #[storage_mapper("owner_assets")]
    fn owner_assets(&self, owner: &ManagedAddress) -> UnorderedSetMapper<ManagedBuffer>;

    #[storage_mapper("whitelisted_addresses")]
    fn whitelisted_addresses(&self) -> UnorderedSetMapper<ManagedAddress>;

    #[storage_mapper("admin_whitelist")]
    fn admin_whitelist(&self) -> UnorderedSetMapper<ManagedAddress>;


}
