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
    pub mod cctp;
    pub mod ekubo;
    pub mod hyperlane;
    pub mod lz;
    pub mod paradex_gigavault;
    pub mod pragma;
    pub mod starkgate;
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
    pub mod paradex_gigavault_middleware {
        pub mod interface;
        pub mod paradex_gigavault_middleware;
    }
    pub mod avnu_middleware {
        pub mod avnu_middleware;
        pub mod errors;
        pub mod interface;
    }

    pub mod starkgate_middleware {
        pub mod errors;
        pub mod interface;
        pub mod starkgate_middleware;
    }
    pub mod hyperlane_middleware {
        pub mod errors;
        pub mod hyperlane_middleware;
        pub mod interface;
    }

    pub mod cctp_middleware {
        pub mod cctp_middleware;
        pub mod errors;
        pub mod interface;
    }
    pub mod lz_middleware {
        pub mod errors;
        pub mod interface;
        pub mod lz_middleware;
    }
    pub mod base_middleware {
        pub mod base_middleware;
        pub mod errors;
        pub mod interface;
    }
}

pub mod adapters {
    pub mod ekubo_adapter {
        pub mod ekubo_adapter;
        pub mod errors;
        pub mod interface;
    }
}


pub mod pods {
    pub mod base_pod;
    pub mod components {
        pub mod asset_transfer_pod;
        pub mod errors;
        pub mod interface;
    }
}

pub mod decoders_and_sanitizers {
    pub mod base_decoder_and_sanitizer;
    pub mod decoder_custom_types;
    pub mod forgeyields_paradex_decoder_and_sanitizer;
    pub mod fyWBTC_decoder_and_sanitizer;
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
    pub mod paradex_gigavault_decoder_and_sanitizer {
        pub mod interface;
        pub mod paradex_gigavault_decoder_and_sanitizer;
    }
    pub mod starkgate_decoder_and_sanitizer {
        pub mod interface;
        pub mod starkgate_decoder_and_sanitizer;
    }
    pub mod starkgate_middleware_decoder_and_sanitizer {
        pub mod interface;
        pub mod starkgate_middleware_decoder_and_sanitizer;
    }
    pub mod hyperlane_decoder_and_sanitizer {
        pub mod hyperlane_decoder_and_sanitizer;
        pub mod interface;
    }
    pub mod hyperlane_middleware_decoder_and_sanitizer {
        pub mod hyperlane_middleware_decoder_and_sanitizer;
        pub mod interface;
    }
    pub mod cctp_decoder_and_sanitizer {
        pub mod cctp_decoder_and_sanitizer;
        pub mod interface;
    }
    pub mod lz_decoder_and_sanitizer {
        pub mod interface;
        pub mod lz_decoder_and_sanitizer;
    }
    pub mod lz_middleware_decoder_and_sanitizer {
        pub mod interface;
        pub mod lz_middleware_decoder_and_sanitizer;
    }
    pub mod cctp_middleware_decoder_and_sanitizer {
        pub mod cctp_middleware_decoder_and_sanitizer;
        pub mod interface;
    }
    pub mod ekubo_adapter_decoder_and_sanitizer {
        pub mod ekubo_adapter_decoder_and_sanitizer;
        pub mod interface;
    }

    pub mod defi_spring_decoder_and_sanitizer {
        pub mod defi_spring_decoder_and_sanitizer;
        pub mod interface;
    }
    pub mod migration_usdc_decoder_and_sanitizer {
        pub mod interface;
        pub mod migration_usdc_decoder_and_sanitizer;
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
    pub mod creator {
        // pub mod creator;
        pub mod creator_fyWBTC;
        pub mod creator_sdk_test;
    }
    pub mod utils;
    pub mod middleware {
        pub mod base_middleware;
        pub mod cctp_middleware;
        pub mod hyperlane_middleware;
        pub mod lz_middleware;
        pub mod starkgate_middleware;
    }
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

    pub mod adapters {
        pub mod ekubo_adapter;
    }
}


pub mod merkle_tree {
    pub mod base;
    pub mod registery;
    pub mod integrations {
        pub mod avnu;
        pub mod cctp;
        pub mod defi_spring;
        pub mod ekubo_adapter;
        pub mod erc4626;
        pub mod extended;
        pub mod hyperlane;
        pub mod lz;
        pub mod migration_usdc;
        pub mod starkgate;
        pub mod starknet_vault_kit_strategies;
        pub mod vesu_v1;
        pub mod vesu_v2;
    }
}
