#!/usr/bin/env python3
"""
Script to convert hex root to vector of bytes for Move
"""

import sys

def hex_to_vector(hex_string):
    """
    Converts hex string to vector of bytes for Move
    """
    # Remove 0x prefix if present
    if hex_string.startswith('0x'):
        hex_string = hex_string[2:]
    
    # Check that string has even length
    if len(hex_string) % 2 != 0:
        raise ValueError("Hex string must have even length")
    
    # Split into pairs of characters and convert to decimal numbers
    bytes_list = []
    for i in range(0, len(hex_string), 2):
        hex_byte = hex_string[i:i+2]
        decimal_byte = int(hex_byte, 16)
        bytes_list.append(str(decimal_byte))
    
    # Form vector for Move
    vector_string = f"vector[{','.join(bytes_list)}]"
    
    return vector_string, bytes_list

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 convert_root_to_vector.py <hex_root>")
        print("Example: python3 convert_root_to_vector.py 0x738c3bae3b0634ed4047cfdc92f4a12b6f62fdaea82f2904d6bfa5867cd2be9b")
        sys.exit(1)
    
    hex_root = sys.argv[1]
    
    try:
        vector_string, bytes_list = hex_to_vector(hex_root)
        print(vector_string)
            
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
