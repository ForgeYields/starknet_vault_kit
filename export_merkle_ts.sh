#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
PKG="vault_allocator"
TEST="vault_allocator::test::creator::test_creator"
OUT_DIR="leafs"

# Nom du fichier = premier argument (sinon "merkle")
NAME="${1:-merkle}"
OUT_PATH="$OUT_DIR/$NAME.json"
LOG_PATH="$OUT_DIR/$NAME.log"

mkdir -p "$OUT_DIR"

# --- Run test ---
snforge test -p "$PKG" "$TEST" 2>&1 | tee "$LOG_PATH" >/dev/null

# --- Parse output using TypeScript ---
cd scripts && pnpm exec tsx exportMerkle.ts "../$LOG_PATH" "../$OUT_PATH"
