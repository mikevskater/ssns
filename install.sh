#!/bin/bash
# SSNS Node.js Backend Installation Script
# Automatically installs Node.js dependencies and registers remote plugin

set -e

echo "🚀 Installing SSNS Node.js Backend..."

# Get the plugin directory
PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE_PLUGIN_DIR="$PLUGIN_DIR/rplugin/node/ssns-db"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js found: $(node --version)"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm is not installed"
    exit 1
fi

echo "✅ npm found: $(npm --version)"

# Check if global neovim package is installed
if ! npm list -g neovim &> /dev/null; then
    echo "📦 Installing global neovim package..."
    npm install -g neovim
else
    echo "✅ Global neovim package already installed"
fi

# Install plugin dependencies
if [ -d "$NODE_PLUGIN_DIR" ]; then
    echo "📦 Installing SSNS Node.js dependencies..."
    cd "$NODE_PLUGIN_DIR"
    npm install --production
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Error: Node plugin directory not found: $NODE_PLUGIN_DIR"
    exit 1
fi

echo ""
echo "✅ SSNS Node.js Backend installed successfully!"
echo ""
echo "⚠️  IMPORTANT: You must restart Neovim and run :UpdateRemotePlugins"
echo "   Then restart Neovim again for the plugin to work."
echo ""
