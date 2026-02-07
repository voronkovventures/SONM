#!/bin/bash
# Generate Go bindings for SONM Modern contracts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
BINDINGS_DIR="$PROJECT_ROOT/blockchain/bindings"
CONTRACTS_DIR="$PROJECT_ROOT/out"

echo "🔧 Generating Go bindings for SONM Modern..."

# Check prerequisites
if ! command -v abigen &> /dev/null; then
    echo "❌ abigen not found. Installing..."
    go install github.com/ethereum/go-ethereum/cmd/abigen@latest
fi

# Create bindings directory
mkdir -p "$BINDINGS_DIR"

# Generate bindings for each contract
echo "📄 Generating SNMToken binding..."
abigen --abi="$CONTRACTS_DIR/SNMToken.sol/SNMToken.json" \
       --pkg=bindings \
       --type=SNMToken \
       --out="$BINDINGS_DIR/snm_token.go"

echo "📄 Generating ProfileRegistry binding..."
abigen --abi="$CONTRACTS_DIR/ProfileRegistry.sol/ProfileRegistry.json" \
       --pkg=bindings \
       --type=ProfileRegistry \
       --out="$BINDINGS_DIR/profile_registry.go"

echo "📄 Generating SONMMarketplace binding..."
abigen --abi="$CONTRACTS_DIR/SONMMarketplace.sol/SONMMarketplace.json" \
       --pkg=bindings \
       --type=SONMMarketplace \
       --out="$BINDINGS_DIR/sonm_marketplace.go"

echo "✅ Go bindings generated successfully!"
echo ""
echo "📁 Output directory: $BINDINGS_DIR"
echo ""
echo "Generated files:"
ls -la "$BINDINGS_DIR"
