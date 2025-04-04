module option_coin::option_coin {
    use sui::coin::{Self, TreasuryCap, Coin};
    use sui::object::{Self, ID, UID};
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::balance::{Self, Balance};
    use sui::event;
    use std::option;
    use distribution::common;

    /// Баланс с информацией об эпохе создания
    public struct EpochBalance<T> has store {
        balance: Balance<T>,
        epoch: u64,
    }

    /// Обертка над Coin, которая связывает монету с эпохой
    public struct EpochCoin<T> has key {
        id: UID,
        coin: Coin<T>,
        epoch: u64,
    }

    /// Событие создания нового токена эпохи
    public struct EpochTokenCreated has copy, drop {
        epoch: u64,
        token_id: ID,
    }

    public struct OptionFactory has drop {}

    public fun create_coin(ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            OptionFactory {},
            6,
            b"OPTION_COIN",
            b"",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// Создает новый токен для эпохи
    public fun mint_epoch_token<T>(
        cap: &mut TreasuryCap<T>,
        amount: u64,
        epoch: u64,
        ctx: &mut TxContext
    ): EpochCoin<T> {
        let coin = coin::mint(cap, amount, ctx);
        let epoch_coin = EpochCoin {
            id: object::new(ctx),
            coin,
            epoch,
        };
        
        // Эмитим событие о создании токена
        event::emit(EpochTokenCreated {
            epoch,
            token_id: object::id(&epoch_coin),
        });
        
        epoch_coin
    }

    /// Передает токен получателю
    public fun transfer<T>(epoch_coin: EpochCoin<T>, recipient: address) {
        transfer::public_transfer(epoch_coin, recipient);
    }

    /// Получает эпоху токена
    public fun epoch<T>(epoch_coin: &EpochCoin<T>): u64 {
        epoch_coin.epoch
    }

    /// Разделяет токен на две части
    public fun split<T>(epoch_coin: &mut EpochCoin<T>, amount: u64, ctx: &mut TxContext): EpochCoin<T> {
        let split_coin = coin::split(&mut epoch_coin.coin, amount, ctx);
        EpochCoin {
            id: object::new(ctx),
            coin: split_coin,
            epoch: epoch_coin.epoch,
        }
    }

    /// Объединяет два токена одной эпохи
    public fun join<T>(epoch_coin1: &mut EpochCoin<T>, epoch_coin2: EpochCoin<T>) {
        assert!(epoch_coin1.epoch == epoch_coin2.epoch, 0);
        let EpochCoin { id, coin, epoch: _ } = epoch_coin2;
        coin::join(&mut epoch_coin1.coin, coin);
        object::delete(id);
    }

    /// Преобразует токен в баланс для использования в reward и gauge контрактах
    public fun into_balance<T>(epoch_coin: EpochCoin<T>): EpochBalance<T> {
        let EpochCoin { id, coin, epoch } = epoch_coin;
        object::delete(id);
        EpochBalance {
            balance: coin::into_balance(coin),
            epoch,
        }
    }

    /// Создает токен из баланса (используется в reward и gauge контрактах)
    /// Проверяет, что эпоха соответствует текущей
    public fun from_balance<T>(
        balance: Balance<T>, 
        epoch: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): EpochCoin<T> {
        let current_epoch = common::epoch_start(common::current_timestamp(clock));
        assert!(epoch == current_epoch, 0);
        
        let coin = coin::from_balance(balance, ctx);
        EpochCoin {
            id: object::new(ctx),
            coin,
            epoch,
        }
    }

    /// Получает значение токена
    public fun value<T>(epoch_coin: &EpochCoin<T>): u64 {
        coin::value(&epoch_coin.coin)
    }

    /// Получает эпоху баланса
    public fun balance_epoch<T>(epoch_balance: &EpochBalance<T>): u64 {
        epoch_balance.epoch
    }

    /// Получает баланс из EpochBalance
    public fun balance<T>(epoch_balance: EpochBalance<T>): Balance<T> {
        let EpochBalance { balance, epoch: _ } = epoch_balance;
        balance
    }
}
