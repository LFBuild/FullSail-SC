module clmm_pool::utils {
    public fun str(mut number: u64): std::string::String {
        if (number == 0) {
            return std::string::utf8(b"0")
        };
        let mut digits = std::vector::empty<u8>();
        while (number > 0) {
            let digit = (number % 10) as u8;
            number = number / 10;
            std::vector::push_back<u8>(&mut digits, digit + 48);
        };
        std::vector::reverse<u8>(&mut digits);
        std::string::utf8(digits)
    }

    // decompiled from Move bytecode v6
}

