import re

def generate_sql_from_osail_info():
    """
    Parses the osail_info.txt file to extract token information and generates
    SQL INSERT statements.
    """
    try:
        with open('osail_info.txt', 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print("Error: 'osail_info.txt' file not found.")
        return

    # This regex finds each object block like `...:{"key":"value",...}`.
    # It handles nested braces by matching non-brace characters or balanced braces.
    object_blocks = re.findall(r'\d+:({\s*(?:[^{}]|\{[^{}]*\})*\s*})', content)

    tokens_data = {}

    # Regexes for extraction from a block
    re_object_type = re.compile(r'"objectType":string"([^"]+)"')
    re_object_id = re.compile(r'"objectId":string"([^"]+)"')
    re_token_info = re.compile(r'<(.*::osail_(\d+)[a-z]+\d+_\d+::OSAIL_\d+[A-Z]+\d+_\d+)>')

    for block in object_blocks:
        object_type_match = re_object_type.search(block)
        if not object_type_match:
            continue
        
        object_type = object_type_match.group(1)
        
        token_info_match = re_token_info.search(object_type)
        if not token_info_match:
            continue
            
        full_token_type = token_info_match.group(1)
        token_num = int(token_info_match.group(2))

        # Extract time slot from the token type (e.g., 0600, 1200, 1800, 0000)
        time_match = re.search(r'_(\d{4})::', full_token_type)
        if not time_match:
            continue
        time_slot = time_match.group(1)
        
        # Create a unique key for each day+time combination
        token_key = f"{token_num}_{time_slot}"
        
        if token_key not in tokens_data:
            tokens_data[token_key] = {}
            
        object_id_match = re_object_id.search(block)
        if not object_id_match:
            continue
        object_id = object_id_match.group(1)

        if 'CoinMetadata' in object_type:
            tokens_data[token_key]['token_address'] = full_token_type
            tokens_data[token_key]['coin_metadata'] = object_id
            tokens_data[token_key]['day'] = token_num
            tokens_data[token_key]['time_slot'] = time_slot
        elif 'TreasuryCap' in object_type:
            tokens_data[token_key]['treasury_cap'] = object_id

    # Sort tokens by day and time slot
    sorted_tokens = sorted(tokens_data.items(), key=lambda x: (x[1]['day'], x[1]['time_slot']))
    
    if len(sorted_tokens) != 20:
        print(f"Warning: Found {len(sorted_tokens)} tokens, expected 20. SQL file will not be created.")
        return

    base_epoch = 1756296000000+21600000
    epoch_increment = 21600000

    sql_header = "INSERT INTO public.osail_distributions (epoch_start, token_address, treasury_cap, coin_metadata)\nVALUES"
    
    values = []
    all_data_found = True
    for i, (token_key, data) in enumerate(sorted_tokens):
        if not all(k in data for k in ['token_address', 'treasury_cap', 'coin_metadata']):
            print(f"Warning: Missing data for token {token_key}. Skipping.")
            all_data_found = False
            continue

        epoch_start = base_epoch + (i * epoch_increment)
        token_address = data['token_address']
        treasury_cap = data['treasury_cap']
        coin_metadata = data['coin_metadata']
        
        value_str = f"({epoch_start}, '{token_address}', '{treasury_cap}', '{coin_metadata}')"
        values.append(value_str)

    if not all_data_found:
        print("Warning: Not all token data was found. SQL file will not be created.")
        return

    sql_script = f"{sql_header}\n" + ",\n".join(values) + ";"

    try:
        with open('insert_osail.sql', 'w') as f:
            f.write(sql_script)
        print("SQL script successfully generated and saved to 'insert_osail.sql'.")
    except IOError as e:
        print(f"Error writing to 'insert_osail.sql': {e}")

if __name__ == "__main__":
    generate_sql_from_osail_info() 