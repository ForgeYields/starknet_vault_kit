// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

pub mod vault_allocator {
    pub mod errors;
    pub mod interface;
    pub mod vault_allocator;
}

pub mod manager {
    pub mod errors;
    pub mod interface;
    pub mod manager;
}

pub mod integration_interfaces {
    pub mod avnu;
    pub mod pragma;
    pub mod vesu_v1;
    pub mod vesu_v2;
}

pub mod periphery {
    pub mod price_router {
        pub mod errors;
        pub mod interface;
        pub mod price_router;
    }
    pub mod price_router_vesu {
        pub mod errors;
        pub mod interface;
        pub mod price_router_vesu;
    }
}

pub mod middlewares {
    pub mod avnu_middleware {
        pub mod avnu_middleware;
        pub mod errors;
        pub mod interface;
    }
}

pub mod decoders_and_sanitizers {
    pub mod base_decoder_and_sanitizer;
    pub mod decoder_custom_types;
    pub mod interface;
    pub mod simple_decoder_and_sanitizer;
    pub mod vesu_v2_specific_decoder_and_sanitizer;
    pub mod avnu_exchange_decoder_and_sanitizer {
        pub mod avnu_exchange_decoder_and_sanitizer;
        pub mod interface;
    }
    pub mod erc4626_decoder_and_sanitizer {
        pub mod erc4626_decoder_and_sanitizer;
        pub mod interface;
    }
    pub mod vesu_decoder_and_sanitizer {
        pub mod interface;
        pub mod vesu_decoder_and_sanitizer;
    }
    pub mod starknet_vault_kit_decoder_and_sanitizer {
        pub mod interface;
        pub mod starknet_vault_kit_decoder_and_sanitizer;
    }
    pub mod vesu_v2_decoder_and_sanitizer {
        pub mod interface;
        pub mod vesu_v2_decoder_and_sanitizer;
    }

    pub mod multiply_decoder_and_sanitizer {
        pub mod interface;
        pub mod multiply_decoder_and_sanitizer;
    }
    
    pub mod defi_spring_snf_style {
        pub mod defi_spring_snf_style_decoder_and_sanitizer;
        pub mod interface;
    }
}

pub mod mocks {
    pub mod counter;
    pub mod erc20;
    pub mod erc4626;
    pub mod vault;
}

#[cfg(test)]
pub mod test {
    // pub mod creator;
    pub mod utils;
    pub mod units {
        pub mod manager;
        pub mod vault_allocator;
    }
    pub mod integrations {
        pub mod avnu;
        pub mod vault_bring_liquidity;
        pub mod vesu_v1;
    }
    pub mod scenarios {
        pub mod stable_carry_loop;
    }
}


pub mod merkle_tree {
    pub mod base;
    pub mod registery;
    pub mod integrations {
        pub mod avnu;
        pub mod erc4626;
        pub mod starknet_vault_kit_strategies;
        pub mod vesu_v1;
        pub mod vesu_v2;
    }
}
