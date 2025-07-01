#![no_std]

multiversx_sc::imports!();
multiversx_sc::derive_imports!();

// Status of the asset
#[derive(TypeAbi, TopEncode, TopDecode, NestedEncode, NestedDecode)]
pub enum Status {
    Available,
    Cancel,
    Repair,
}

// Asset struct
#[derive(TypeAbi, TopEncode, TopDecode, NestedEncode, NestedDecode)]
pub struct Asset<M: ManagedTypeApi> {
    code: ManagedBuffer<M>,
    name: ManagedBuffer<M>,
    location: ManagedBuffer<M>,
    status: Status,
    owner: ManagedAddress<M>,
}

#[multiversx_sc::contract]
pub trait AssetLoan {
    // Initialize the contract with the initial whitelist of authorized addresses
    #[init]
    fn init(&self, initial_whitelist: MultiValueEncoded<ManagedAddress>) {
        // Initialize whitelist with provided addresses
        let whitelist = self.whitelisted_addresses();
        for address in initial_whitelist {
            whitelist.insert(address);
        }
    }

    #[upgrade]
    fn upgrade(&self, new_whitelist: MultiValueEncoded<ManagedAddress>) {
        // Clear existing whitelist
        self.whitelisted_addresses().clear();
        
        // Add new addresses to whitelist
        let whitelist = self.whitelisted_addresses();
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
        self.whitelisted_addresses().remove(&address);
    }

    #[view(isWhitelisted)]
    fn is_whitelisted(&self, address: &ManagedAddress) -> bool {
        self.whitelisted_addresses().contains(address)
    }

    #[endpoint(registerAsset)]
    fn register_asset(
        &self,
        code: ManagedBuffer,
        name: ManagedBuffer,
        location: ManagedBuffer,
    ) {
        let caller = self.blockchain().get_caller();
        require!(
            self.is_whitelisted(&caller),
            "Only whitelisted addresses can register assets"
        );
        require!(self.asset(&code).is_empty(), "Asset already registered");

        let asset = Asset {
            code: code.clone(),
            name,
            location,
            status: Status::Available,
            owner: caller.clone(),
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
        let mut asset = self.asset(&code).get().unwrap_or_else(|| sc_panic!("Asset not found"));
        
        // Update the status
        asset.status = new_status;
        
        // Save the updated asset
        self.asset(&code).set(asset);
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
            if let Some(asset) = self.asset(&asset_code).get() {
                result.push(asset);
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
