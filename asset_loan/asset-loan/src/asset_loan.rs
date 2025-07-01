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
    // Initialize the contract with the initial whitelist of authorized addresses
    #[init]
    fn init(&self, initial_whitelist: MultiValueEncoded<ManagedAddress>) {
        // Initialize whitelist with provided addresses
        let mut whitelist = self.whitelisted_addresses();
        for address in initial_whitelist {
            whitelist.insert(address);
        }
    }

    #[upgrade]
    fn upgrade(&self, new_whitelist: MultiValueEncoded<ManagedAddress>) {
        // Clear existing whitelist
        self.whitelisted_addresses().clear();
        
        // Add new addresses to whitelist
        let mut whitelist = self.whitelisted_addresses();
        for address in new_whitelist {
            whitelist.insert(address);
        }
    }

    // Endpoints

    // Whitelist endpoints
    #[only_owner]
    #[endpoint(addToWhitelist)]
    fn add_to_whitelist(&self, address: ManagedAddress) {
        self.whitelisted_addresses().insert(address);
    }

    #[only_owner]
    #[endpoint(removeFromWhitelist)]
    fn remove_from_whitelist(&self, address: ManagedAddress) {
        self.whitelisted_addresses().swap_remove(&address);
    }

    #[view(isWhitelisted)]
    fn is_whitelisted(&self, address: &ManagedAddress) -> bool {
        self.whitelisted_addresses().contains(address)
    }

    #[only_owner]
    #[endpoint(registerAsset)]
    fn register_asset(
        &self,
        code: ManagedBuffer,
        name: ManagedBuffer,
        location: ManagedBuffer,
    ) {
        let caller = self.blockchain().get_caller();
        require!(self.asset(&code).is_empty(), "Asset already registered");

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
    
    #[only_owner]
    #[endpoint(changeAssetStatus)]
    fn change_asset_status(&self, code: ManagedBuffer, new_status: Status) {
        // Get the asset
        require!(!self.asset(&code).is_empty(), "Asset not found");
        let mut asset = self.asset(&code).get();
        
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
        borrower: ManagedAddress,
        duration: u64,
    ) {
        require!(!self.asset(&asset_code).is_empty(), "Asset not found");
        let mut asset = self.asset(&asset_code).get();
        require!(asset.status == Status::Available, "Asset is not available for loan");
        
        let current_timestamp = self.blockchain().get_block_timestamp();
        
        // Update asset
        asset.status = Status::Loan;
        asset.borrower = Some(borrower);
        asset.loan_end_timestamp = Some(current_timestamp + duration);
        
        self.asset(&asset_code).set(asset);
    }

    #[endpoint(returnAsset)]
    fn return_asset(&self, asset_code: ManagedBuffer) {
        let caller = self.blockchain().get_caller();
        require!(!self.asset(&asset_code).is_empty(), "Asset not found");
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

    // Views
    #[view(getMyAssets)]
    fn get_my_assets(&self) -> MultiValueEncoded<Asset<Self::Api>> {
        let caller = self.blockchain().get_caller();
        require!(
            self.is_whitelisted(&caller),
            "Only whitelisted addresses can view their assets"
        );

        let mut result = MultiValueEncoded::new();
        
        for asset_code in self.owner_assets(&caller).iter() {
            if !self.asset(&asset_code).is_empty() {
                result.push(self.asset(&asset_code).get());
            }
        }
        
        result
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
}
