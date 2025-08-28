import argparse
import math
from datetime import datetime, timedelta, timezone

def get_next_epoch_start(now, duration_hours):
    duration_seconds = duration_hours * 3600
    if duration_seconds == 0:
        return now.replace(microsecond=0)

    now_ts = now.timestamp()
    
    # Using math.ceil to find the multiple of duration_seconds that is >= now_ts
    num_epochs = math.ceil(now_ts / duration_seconds)
    next_epoch_start_ts = num_epochs * duration_seconds
    
    return datetime.fromtimestamp(next_epoch_start_ts, tz=timezone.utc)

def generate_osail_code(expiry_date, icon_number, duration_hours):
    if duration_hours < 24:
        date_str = expiry_date.strftime('%d%b%Y_%H%M')
        symbol_date_str = expiry_date.strftime('%d%b%Y-%H%M')
    else:
        date_str = expiry_date.strftime('%d%b%Y')
        symbol_date_str = expiry_date.strftime('%d%b%Y')
    
    module_name = f"osail_{date_str.lower()}"
    struct_name = f"OSAIL_{date_str.upper()}"
    token_name_symbol = f"oSAIL-{symbol_date_str}"
    description = f"Full Sail option token, expiration {expiry_date.strftime('%d %b %Y %H:%M:%S')} UTC"
    url = f"https://app.fullsail.finance/static_files/o_sail_coin.png"

    template = f"""module osail::{module_name} {{
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{{Self as tx_context, TxContext}};

    public struct {struct_name} has drop {{}}

    fun init(otw: {struct_name}, ctx: &mut TxContext) {{
        let url = url::new_unsafe(ascii::string(b"{url}"));
        let (treasury_cap, metadata) = coin::create_currency<{struct_name}>(
            otw,
            6,
            b"{token_name_symbol}",
            b"{token_name_symbol}",
            b"{description}",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }}
}}"""
    return module_name, template.strip()

def main():
    parser = argparse.ArgumentParser(description="Generate oSAIL token Move code.")
    parser.add_argument("epoch_duration", choices=["3h", "6h", "7d"], help="Epoch duration (3h, 6h or 7d)")
    args = parser.parse_args()

    if args.epoch_duration == "3h":
        duration_hours = 3
    elif args.epoch_duration == "6h":
        duration_hours = 6
    else:
        duration_hours = 7 * 24
    epoch_duration = timedelta(hours=duration_hours)

    now = datetime.now(timezone.utc)
    next_epoch_start = get_next_epoch_start(now, duration_hours)

    first_expiry = next_epoch_start + 5 * epoch_duration

    for i in range(20):
        expiry_date = first_expiry + i * epoch_duration
        module_name, code = generate_osail_code(expiry_date, i + 1, duration_hours)
        file_path = f"../sources/{module_name}.move"
        with open(file_path, "w") as f:
            f.write(code)
        print(f"Generated {file_path}")

if __name__ == "__main__":
    main()
