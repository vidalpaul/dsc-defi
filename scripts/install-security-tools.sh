#!/bin/bash

# Security Tools Installation Script for DSC Protocol
# This script installs all required security analysis tools

set -e

echo "🔒 Installing Security Tools for DSC Protocol"
echo "=============================================="

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed. Please install Node.js first."
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 is required but not installed. Please install Python3 first."
    exit 1
fi

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Rust is required but not installed. Please install Rust first."
    echo "Visit: https://rustup.rs/"
    exit 1
fi

echo ""
echo "📦 Installing Solhint..."
if npm install -g solhint; then
    echo "✅ Solhint installed successfully"
else
    echo "⚠️  Failed to install Solhint"
fi

echo ""
echo "🐍 Installing Slither..."
if pip3 install slither-analyzer; then
    echo "✅ Slither installed successfully"
else
    echo "⚠️  Failed to install Slither"
fi

echo ""
echo "🦀 Installing Aderyn..."
if cargo install aderyn; then
    echo "✅ Aderyn installed successfully"
else
    echo "⚠️  Failed to install Aderyn"
fi

echo ""
echo "🦄 Installing Echidna..."
echo "Note: Echidna installation varies by platform"

# Detect OS and provide installation instructions
OS="$(uname -s)"
case "${OS}" in
    Linux*)
        echo "For Ubuntu/Debian:"
        echo "  wget https://github.com/crytic/echidna/releases/latest/download/echidna-x86_64-linux.tar.gz"
        echo "  tar -xzf echidna-x86_64-linux.tar.gz"
        echo "  sudo mv echidna /usr/local/bin/"
        ;;
    Darwin*)
        if command -v brew &> /dev/null; then
            echo "Installing via Homebrew..."
            if brew install echidna; then
                echo "✅ Echidna installed successfully"
            else
                echo "⚠️  Failed to install Echidna via Homebrew"
                echo "Try manual installation:"
                echo "  wget https://github.com/crytic/echidna/releases/latest/download/echidna-x86_64-macos.tar.gz"
                echo "  tar -xzf echidna-x86_64-macos.tar.gz"
                echo "  sudo mv echidna /usr/local/bin/"
            fi
        else
            echo "Manual installation required:"
            echo "  wget https://github.com/crytic/echidna/releases/latest/download/echidna-x86_64-macos.tar.gz"
            echo "  tar -xzf echidna-x86_64-macos.tar.gz"
            echo "  sudo mv echidna /usr/local/bin/"
        fi
        ;;
    *)
        echo "Please install Echidna manually from:"
        echo "https://github.com/crytic/echidna/releases"
        ;;
esac

echo ""
echo "🔍 Verifying installations..."

# Verify installations
echo -n "Solhint: "
if command -v solhint &> /dev/null; then
    echo "✅ $(solhint --version)"
else
    echo "❌ Not found"
fi

echo -n "Slither: "
if command -v slither &> /dev/null; then
    echo "✅ $(slither --version)"
else
    echo "❌ Not found"
fi

echo -n "Aderyn: "
if command -v aderyn &> /dev/null; then
    echo "✅ $(aderyn --version)"
else
    echo "❌ Not found"
fi

echo -n "Echidna: "
if command -v echidna &> /dev/null; then
    echo "✅ $(echidna --version)"
else
    echo "❌ Not found"
fi

echo ""
echo "🎉 Installation Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Run 'make security' to execute all security tools"
echo "2. Review the security checklist in security-checklist.md"
echo "3. Check tool-specific configurations:"
echo "   - .solhint.json (Solhint config)"
echo "   - slither.config.json (Slither config)"
echo "   - aderyn.toml (Aderyn config)"
echo "   - echidna.yaml (Echidna config)"
echo ""
echo "🔒 Security Analysis Commands:"
echo "  make security      - Run all security tools"
echo "  make solhint       - Solidity linting"
echo "  make slither       - Static analysis"
echo "  make aderyn        - Advanced security scan"
echo "  make echidna       - Property-based testing"
echo ""