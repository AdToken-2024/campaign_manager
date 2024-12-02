/// Module: campaign_manager
module campaign_manager::campaign_manager {

    use sui::table::{Table, Self};
    use sui::tx_context::{sender, TxContext};
    use sui::vec_map::{Self, VecMap};
  
    const CAMPAIGN_STATS_VERSION: u64 = 1;
    const CAMPAIGN_VERSION: u64 = 1;
    const ADVERTISER_VERSION: u64 = 1;
    const PARTNER_VERSION: u64 = 1;
    const PARTNER_CAMPAIGN_STATS_VERSION: u64 = 1;


    // Error codes
    const UNAUTHORIZED: u64 = 0; // Error code for unauthorized access
    const INVALID_VERSION: u64 = 1; // Error code for unauthorized access
    const INVALID_VALUE: u64 = 2;
    const INVALID_EXPIRATION_DATE_1: u64 = 3;
    const INVALID_EXPIRATION_DATE_2: u64 = 4;
    const CAMPAIGN_IS_NOT_ACTIVE: u64 = 5;
    const CAMPAIGN_IS_NOT_STOPPED: u64 = 6;
    const ALREADY_PARTICIPATED: u64 = 7;
    const NOT_PARTICIPATED: u64 = 8;
    const INSUFFICIENT_BUDGET: u64 = 9;

    public struct AdminCap has key, store {
        id: UID
    }

    public struct CampaignStats has key, store {
        id: UID,
        version: u64,
        campaign_count: u64,
        expired_campaign_count: u64,
        advertiser_count: u64,
        partner_count: u64,
        clicks_generated: u64,
        views_generated: u64,
        total_ad_spent: u64,
    }

    // Campaign Structure
    public struct Campaign has key, store {
        id: UID,
        mapping_id: ID,
        version: u64,
        advertiser: ID, // advertise ID
        category: vector<u8>,
        cost_per_click: u64,
        cost_per_1000_views: u64,
        views_count: u64,
        clicks_count: u64,
        total_budget: u64,
        remaining_budget: u64,
        status: u64, // 0: Active, 1: InActive, 2: Stopped
        start_date: u64,
        end_date: u64,
        partners: vector<ID>, // Partner UID, Campaign
    }

    // Advertiser structure holding basic info
    public struct Advertiser has key, store {
        id: UID,
        version: u64,
        company_name: vector<u8>,
        company_website: vector<u8>,
        company_logo: vector<u8>,
        x_profile_name: vector<u8>,
        wallet_address: address, // type of wallet add
        total_views: u64,
        total_clicks: u64,
        total_spent: u64, // Add more fields as needed in future versions
        campaigns: vector<ID>,
    }

    public struct Partner has key, store {
        id: UID,
        version: u64,
        x_profile_name: vector<u8>,
        wallet_address: address,
        campaigns_count: u64,
        clicks_generated: u64,
        views_generated: u64,
        total_earnings: u64,
        is_publisher: u64, // 0: Influncer; 1: Publisher
        campaigns: VecMap<ID, ID>, //Campaign -> PartnerCampaignStats
    }

    public struct PartnerCampaignStats has key, store {
        id: UID,
        version: u64,
        affliate_id: ID,
        campaign_id: ID,
        clicks_generated: u64,
        views_generated: u64,
        total_earnings: u64,
    }

    public struct CampaignCreatedEvent has copy, drop {
        campaign_id: ID,
        creator: address,
        total_budget: u64,
        cost_per_click: u64,
        cost_per_1000_views: u64,
        expiration_time: u64,
        timestamp: u64
    }

    public struct AffiliateCreatedEvent has copy, drop {
        affiliate_id: ID,
        owner: address,
        timestamp: u64
    }

    public struct AffiliateJoinedCampaignEvent has copy, drop {
        campaign_id: ID,
        affiliate_id: ID,
        timestamp: u64
    }

    public struct CampaignBudgetUpdateEvent has copy, drop {
        campaign_id: ID,
        old_budget: u64,
        new_budget: u64,
        timestamp: u64
    }

    public struct AffiliateEarningsEvent has copy, drop {
        campaign_id: ID,
        affiliate_id: ID,
        earnings: u64,
        action_type: u8, // 0 for clicks, 1 for views
        count: u64,
        timestamp: u64
    }

    fun init(ctx: &mut TxContext) {

        let campaign_stats = CampaignStats {
            id: object::new(ctx),
            version: 1,
            campaign_count: 0,
            expired_campaign_count:0,
            advertiser_count: 0,
            partner_count: 0,
            clicks_generated: 0,
            views_generated: 0,
            total_ad_spent: 0,
        };

        transfer::public_transfer(campaign_stats, sender(ctx));

        transfer::public_transfer(
            AdminCap {id: object::new(ctx)},
            sender(ctx)
        );
    }

    // Advertiser
    // Function to create a new Advertiser
    public fun create_advertiser_v1(
        _: &AdminCap,
        company_name: vector<u8>,
        company_website: vector<u8>,
        company_logo: vector<u8>,
        x_profile_name: vector<u8>,
        wallet_address: address,
        chain: vector<u8>,
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
    ) {
        assert!(
            ADVERTISER_VERSION == 1,
            INVALID_VERSION
        );
        let id = object::new(ctx); // Create a new UID for the advertiser
        let version = ADVERTISER_VERSION;
        let total_views = 0; // Initialize total views
        let total_clicks = 0; // Initialize total clicks
        let total_spent = 0; // Initialize total spent
        let campaigns = vector::empty<ID>(); // Initialize an empty campaigns vector

        // Create the Advertiser resource
        let advertiser = Advertiser {
            id,
            version,
            company_name,
            company_website,
            company_logo,
            x_profile_name,
            wallet_address,
            total_views,
            total_clicks,
            total_spent,
            campaigns,
        };

        transfer::public_transfer(advertiser, sender(ctx));
        campaign_stats.advertiser_count = campaign_stats.advertiser_count + 1;
    }

    // Function to create a new campaign (AdminCap required)
    public fun create_campaign_v1(
        _: &AdminCap,
        advertiser: &mut Advertiser,
        category: vector<u8>,
        cost_per_click: u64,
        cost_per_1000_views: u64,
        total_budget: u64,
        end_date: u64,
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
    ) {
        assert!(
            CAMPAIGN_VERSION == 1,
            INVALID_VERSION
        );

        let current_timestamp = ctx.epoch_timestamp_ms();

        assert!(
            end_date >= current_timestamp,
            INVALID_EXPIRATION_DATE_1
        );

        // Create a new UID for the campaign
        let uid = object::new(ctx);
        let campaign_id = object::uid_to_inner(&uid);
        let mapping_id = object::uid_to_inner(&uid);

        let advertiser_id = object::uid_to_inner(&advertiser.id);

        // Initialize the campaign resource
        let campaign = Campaign {
            id: uid,
            mapping_id,
            version: 1,
            advertiser: advertiser_id,
            category,
            cost_per_click,
            cost_per_1000_views,
            views_count: 0,
            clicks_count: 0,
            total_budget,
            remaining_budget: total_budget,
            status: 0, // Active by default
            start_date: ctx.epoch_timestamp_ms(),
            end_date,
            partners: vector::empty<ID>(), // Empty partners list
        };

        // Move the campaign resource to the caller's account
         transfer::public_transfer(campaign, sender(ctx));

        // Increase campaigns count
        campaign_stats.campaign_count = campaign_stats.campaign_count + 1;
        campaign_stats.total_ad_spent = campaign_stats.total_ad_spent + 1;

        // Map campaign to the advertiser
        vector::push_back(&mut advertiser.campaigns, campaign_id);
    }

    // Function to update the campaign's budget
    public fun update_campaign_budget(
        _: &AdminCap, // Ensure only admin can update
        campaign: &mut Campaign, // Campaign to update
        add_budget: u64, // New total budget to set
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
    ) {
        assert!(add_budget > 0, INVALID_VALUE);
        // Update the campaign budget
        campaign.total_budget = campaign.total_budget + add_budget;
        campaign.remaining_budget = campaign.remaining_budget + add_budget;

        campaign_stats.total_ad_spent = campaign_stats.total_ad_spent + add_budget;
    }

    // Function to update the expiration date of a campaign
    public entry fun update_campaign_expiration(
        _: &AdminCap, // Ensure only admin can update
        campaign: &mut Campaign, // Campaign to update
        new_end_date: u64, // New expiration date (in timestamp)
        ctx: &mut TxContext,
    ) {
        // Ensure the new end date is in the future compared to start_date
        assert!(
            new_end_date >= campaign.start_date,
            INVALID_EXPIRATION_DATE_2
        );

        // Update the expiration date
        campaign.end_date = new_end_date;
    }

    fun update_campaign_status_if_expired(
        campaign: &mut Campaign, 
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
        ) {
            // Get the current timestamp in milliseconds
            let current_epoch_ms = tx_context::epoch_timestamp_ms(ctx);

            // Check if the campaign end date is in the past
            if (campaign.end_date < current_epoch_ms) {
                campaign.status = 1; // Inactive
                campaign_stats.expired_campaign_count = campaign_stats.expired_campaign_count + 1;
            }
        }

    // Function to expire of a campaign
    public fun expire_campaign(
        _: &AdminCap, // Ensure only admin can update
        campaign: &mut Campaign, // Campaign to update
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
    ) {
        // Ensure the campaign is active
        assert!(
            campaign.status == 0,
            CAMPAIGN_IS_NOT_ACTIVE
        );

        campaign.status = 1; // Inactive
        campaign_stats.expired_campaign_count = campaign_stats.expired_campaign_count + 1;
    }

    // Function to stop a campaign
    public fun stop_campaign(
        _: &AdminCap, // Ensure only admin can update
        campaign: &mut Campaign, // Campaign to update
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
    ) {
        // Ensure the campaign is active
        assert!(
            campaign.status == 0,
            CAMPAIGN_IS_NOT_ACTIVE
        );

        campaign.status = 2; // stopped
        campaign_stats.expired_campaign_count = campaign_stats.expired_campaign_count + 1;
    }

    // Function to activate a campaign
    public fun activate_campaign(
        _: &AdminCap, // Ensure only admin can update
        campaign: &mut Campaign, // Campaign to update
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
    ) {
        // Check if the campaign has expired before proceeding
        update_campaign_status_if_expired(campaign, campaign_stats, ctx);
        
        // Ensure the campaign is stopped
        assert!(
            campaign.status == 2,
            CAMPAIGN_IS_NOT_STOPPED
        );

        campaign.status = 0; // stopped
        campaign_stats.expired_campaign_count = campaign_stats.expired_campaign_count - 1;
    }

    // Partner

    /// Function to create a new partner
    public fun create_partner_v1(
        _: &AdminCap, // Ensure only admin can update
        x_profile_name: vector<u8>,
        wallet_address: address,
        is_publisher: u64,
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
    ) {

        assert!(
            PARTNER_VERSION == 1,
            INVALID_VERSION
        );
        // Create a new UID for the affiliate
        let partner_id = object::new(ctx); // Create a new UID

        // Initialize the affiliate object
        let partner = Partner {
            id: partner_id,
            version: PARTNER_VERSION,
            x_profile_name,
            wallet_address,
            campaigns_count: 0,
            clicks_generated: 0,
            views_generated: 0,
            total_earnings: 0,
            is_publisher,
            campaigns: vec_map::empty<ID, ID>(), // Empty partners list
        };

        transfer::public_transfer(partner, sender(ctx));

        campaign_stats.partner_count = campaign_stats.partner_count + 1;
    }

    // Participate participate in a campaign function
    public fun participate_in_campaign_v1(
        _: &AdminCap,
        partner: &mut Partner,
        campaign: &mut Campaign,
        campaign_stats: &mut CampaignStats,
        ctx: &mut TxContext,
    ) {

        // Check if the campaign has expired before proceeding
        update_campaign_status_if_expired(campaign, campaign_stats, ctx);

        // Ensure the campaign is active
        assert!(campaign.status == 0, CAMPAIGN_IS_NOT_ACTIVE);
        
        // Check if partner already participated in this campaign
        assert!(!vec_map::contains(&partner.campaigns, &campaign.mapping_id), ALREADY_PARTICIPATED);
        
        // Create AffiliateCampaignStats

        let uid = object::new(ctx);
        let partner_id = object::uid_to_inner(&partner.id);
        let campaign_id = object::uid_to_inner(&campaign.id);

        let affiliate_campaign_stats = PartnerCampaignStats {
            id: uid,
            version: PARTNER_CAMPAIGN_STATS_VERSION,
            affliate_id: partner_id,
            campaign_id: campaign_id,
            clicks_generated: 0,
            views_generated: 0,
            total_earnings: 0,
        };
        
        // Mapping entry to affilaite campaigns
        vec_map::insert(&mut partner.campaigns, campaign_id, partner_id);

        // Increment the affiliate's participation count
        partner.campaigns_count = partner.campaigns_count + 1;

        // Add the affiliate to the campaign's affiliates list
        vector::push_back(&mut campaign.partners, partner_id);
        
        // Save the affiliate on-chain
         transfer::public_transfer(affiliate_campaign_stats, sender(ctx));
    }

    public fun update_partner_click_count( _: &AdminCap,
        partner: &mut Partner,
        campaign: &mut Campaign,
        partner_campaign_stats:  &mut PartnerCampaignStats,
        campaign_stats: &mut CampaignStats,
        clicks_count: u64,
        ctx: &mut TxContext,
        ) {
            // Check if the campaign has expired before proceeding
            update_campaign_status_if_expired(campaign, campaign_stats, ctx);

            // Ensure the campaign is active
            assert!(campaign.status == 0, CAMPAIGN_IS_NOT_ACTIVE);

            // Check affiliate already participated in this campaign
            assert!(vec_map::contains(&partner.campaigns, &campaign.mapping_id), NOT_PARTICIPATED);

             // Calculate required budget for clicks
            let required_budget = (clicks_count * campaign.cost_per_click);
            
            // Ensure campaign has sufficient remaining budget
            assert!(campaign.remaining_budget >= required_budget, INSUFFICIENT_BUDGET);

            // Update remaining budget
            campaign.remaining_budget = campaign.remaining_budget - required_budget;

            // Update earnings tracking
            partner.total_earnings = partner.total_earnings + required_budget;
            partner_campaign_stats.total_earnings = partner_campaign_stats.total_earnings + required_budget;

            // Update stats
            partner_campaign_stats.clicks_generated = partner_campaign_stats.clicks_generated + clicks_count;
            campaign.clicks_count = campaign.clicks_count + clicks_count;
            partner.clicks_generated = partner.clicks_generated + clicks_count;
            campaign_stats.clicks_generated = campaign_stats.clicks_generated + clicks_count;
}

    public fun update_partner_view_count( _: &AdminCap,
        partner: &mut Partner,
        campaign: &mut Campaign,
        partner_campaign_stats:  &mut PartnerCampaignStats,
        campaign_stats: &mut CampaignStats,
        views_count: u64,
        ctx: &mut TxContext,
        ) {

            // Check if the campaign has expired before proceeding
            update_campaign_status_if_expired(campaign, campaign_stats, ctx);
            // Ensure the campaign is active
            assert!(campaign.status == 0, CAMPAIGN_IS_NOT_ACTIVE);

            // Check affiliate already participated in this campaign
            assert!(vec_map::contains(&partner.campaigns, &campaign.mapping_id), NOT_PARTICIPATED);

            // Calculate earnings based on cost per 1000 views
            let earnings = (views_count * campaign.cost_per_1000_views) / 1000;
            
            // Ensure campaign has sufficient remaining budget
            assert!(campaign.remaining_budget >= earnings, INSUFFICIENT_BUDGET);

            // Update remaining budget
            campaign.remaining_budget = campaign.remaining_budget - earnings;

            // Update earnings
            partner.total_earnings = partner.total_earnings + earnings;
            partner_campaign_stats.total_earnings = partner_campaign_stats.total_earnings + earnings;

            // Update stats
            partner_campaign_stats.views_generated = partner_campaign_stats.views_generated + views_count;
            campaign.views_count = campaign.views_count + views_count;
            partner.views_generated = partner.views_generated + views_count;
            campaign_stats.views_generated = campaign_stats.views_generated + views_count;
            campaign_stats.total_ad_spent = campaign_stats.total_ad_spent + earnings;
        }

}
