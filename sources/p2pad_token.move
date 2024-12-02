/// Create a p2pad Token.
module p2pad_token::p2pad_token {
    use sui::coin::{Self, TreasuryCap};
    use sui::tx_context::{sender, TxContext};
    use sui::transfer;
    use std::option;
    use sui::event;

    /// OTW and the type for the Token.
    public struct P2PAD_TOKEN has drop {}

    // Most of the magic happens in the initializer for the demonstration
    // purposes; however half of what's happening here could be implemented as
    // a single / set of PTBs.
    fun init(otw: P2PAD_TOKEN, ctx: &mut TxContext) {
        let treasury_cap = create_currency(otw, ctx);
        transfer::public_transfer(treasury_cap, sender(ctx));
    }

    /// Internal: not necessary, but moving this call to a separate function for
    /// better visibility of the Closed Loop setup in `init`.
    fun create_currency<T: drop>(
        otw: T,
        ctx: &mut TxContext
    ): TreasuryCap<T> {
        let (treasury_cap, metadata) = coin::create_currency(
            otw, 9,
            b"P2PAD",
            b"P2pad Token",
            b"P2PAD Token",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);
        treasury_cap
    }

    /// Event emitted when tokens are minted
    public struct MintEvent has copy, drop {
        minter: address,
        recipient: address,
        amount: u64,
    }

    /// Mint `amount` of `Coin` and send it to `recipient`.
    public entry fun mint(
        c: &mut TreasuryCap<P2PAD_TOKEN>, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(c, amount, recipient, ctx);
        
        // Emit the mint event
        event::emit(MintEvent {
            minter: sender(ctx),
            recipient,
            amount
        });
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext) {
        init(P2PAD_TOKEN{}, ctx);
    }
}

#[test_only]
/// Implements tests for most common scenarios for the coin example.
module p2pad_token::p2pad_token_tests {
    use p2pad_token::p2pad_token::{Self, P2PAD_TOKEN, init_for_test, MintEvent};
    use sui::coin::{Self, TreasuryCap};
    use sui::test_scenario as ts;
    use sui::test_utils::assert_eq;
    use sui::event;
    
    #[test]
    fun mint_transfer_update() {
        let addr1 = @0xA;
        let addr2 = @0xB;
        let amount = 10000000000;

        let mut mut_scenario = ts::begin(addr1);
        {
            init_for_test(ts::ctx(&mut mut_scenario));
        };

        ts::next_tx(&mut mut_scenario, addr1);
        {
            let mut tc = ts::take_from_sender<TreasuryCap<P2PAD_TOKEN>>(&mut mut_scenario);
            p2pad_token::mint(&mut tc, amount, addr2, ts::ctx(&mut mut_scenario));
            ts::return_to_sender(&mut mut_scenario, tc);
        };

        ts::end(mut_scenario);
    }
}