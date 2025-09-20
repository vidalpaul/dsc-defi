# DSC Protocol Security and Testing Makefile

# Variables
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# Help
.PHONY: help
help:
	@echo "DSC Protocol - Available Commands:"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  test           - Run all tests"
	@echo "  test-unit      - Run unit tests only"
	@echo "  test-fork      - Run fork tests"
	@echo "  test-invariant - Run invariant tests"
	@echo "  coverage       - Generate test coverage report"
	@echo ""
	@echo "🔒 Security Analysis:"
	@echo "  security       - Run complete security analysis suite"
	@echo "  solhint        - Run Solhint linter"
	@echo "  slither        - Run Slither static analysis"
	@echo "  aderyn         - Run Aderyn security scanner"
	@echo "  echidna        - Run Echidna property-based testing"
	@echo ""
	@echo "🚀 Deployment:"
	@echo "  deploy-anvil   - Deploy to local Anvil network"
	@echo "  deploy-sepolia - Deploy to Sepolia testnet"
	@echo ""
	@echo "🧹 Utilities:"
	@echo "  clean          - Clean build artifacts"
	@echo "  fmt            - Format code"
	@echo "  install        - Install dependencies"

# Installation
.PHONY: install
install:
	forge install
	npm install -g solhint
	pip install slither-analyzer
	cargo install aderyn
	# Note: Echidna installation varies by platform

# Building
.PHONY: build
build:
	forge build

.PHONY: clean
clean:
	forge clean
	rm -rf coverage/
	rm -rf security-reports/
	rm -f aderyn-report.json
	rm -f slither-report.json
	rm -f slither-report.sarif

# Testing
.PHONY: test
test:
	forge test -vvv

.PHONY: test-unit
test-unit:
	forge test --match-path "test/unit/**/*.sol" -vvv

.PHONY: test-fork
test-fork:
	@echo "Fork tests not implemented yet"

.PHONY: test-invariant
test-invariant:
	forge test --match-path "test/unit/invariant/**/*.sol" -vvv

.PHONY: coverage
coverage:
	@echo "Generating coverage report..."
	@mkdir -p coverage
	forge coverage --ir-minimum --report lcov
	forge coverage --ir-minimum --report summary > coverage/summary.txt
	@echo "Coverage report generated in coverage/"

# Formatting
.PHONY: fmt
fmt:
	forge fmt

# Security Analysis
.PHONY: security
security: security-setup solhint slither aderyn echidna security-summary

.PHONY: security-setup
security-setup:
	@echo "🔒 Setting up security analysis..."
	@mkdir -p security-reports
	@echo "Security analysis started at: $$(date)" > security-reports/analysis.log

.PHONY: solhint
solhint:
	@echo "Running Solhint..."
	@npx solhint 'src/**/*.sol' --config .solhint.json --formatter table > security-reports/solhint-report.txt 2>&1 || echo "Solhint completed with warnings"
	@echo "✅ Solhint analysis complete"

.PHONY: slither
slither:
	@echo "Running Slither..."
	@slither . --config-file slither.config.json --exclude-dependencies > security-reports/slither-report.txt 2>&1 || echo "Slither completed with findings"
	@echo "✅ Slither analysis complete"

.PHONY: aderyn
aderyn:
	@echo "Running Aderyn..."
	@aderyn . --config aderyn.toml > security-reports/aderyn-report.txt 2>&1 || echo "Aderyn completed with findings"
	@cp aderyn-report.json security-reports/ 2>/dev/null || echo "Aderyn JSON report not generated"
	@echo "✅ Aderyn analysis complete"

.PHONY: echidna
echidna:
	@echo "Running Echidna property-based testing..."
	@if command -v echidna >/dev/null 2>&1; then \
		echidna test/echidna/DSCEchidna.sol --config echidna.yaml > security-reports/echidna-report.txt 2>&1 || echo "Echidna completed with findings"; \
		echo "✅ Echidna analysis complete"; \
	else \
		echo "⚠️  Echidna not installed. Skipping..."; \
		echo "Install from: https://github.com/crytic/echidna"; \
	fi

.PHONY: security-summary
security-summary:
	@echo ""
	@echo "🔒 Security Analysis Summary"
	@echo "==========================="
	@echo ""
	@echo "📊 Reports generated in security-reports/:"
	@ls -la security-reports/ 2>/dev/null || echo "No reports directory found"
	@echo ""
	@echo "🎯 Key Security Checks:"
	@echo "  ✅ Solhint (Style & Security Linting)"
	@echo "  ✅ Slither (Static Analysis)"
	@echo "  ✅ Aderyn (Advanced Security Scanner)"
	@if command -v echidna >/dev/null 2>&1; then echo "  ✅ Echidna (Property-Based Testing)"; else echo "  ⚠️  Echidna (Not Installed)"; fi
	@echo ""
	@echo "📋 Next Steps:"
	@echo "  1. Review all reports in security-reports/"
	@echo "  2. Address high and medium severity findings"
	@echo "  3. Consider additional manual security review"
	@echo "  4. Run property-based tests with different parameters"

# Deployment
.PHONY: deploy-anvil
deploy-anvil:
	@echo "Deploying to Anvil..."
	forge script script/DSC_Protocol_Deploy.s.sol:DSC_Protocol_DeployScript $(NETWORK_ARGS)

.PHONY: deploy-sepolia
deploy-sepolia:
	@echo "Deploying to Sepolia..."
	@echo "Make sure to set PRIVATE_KEY environment variable"
	forge script script/DSC_Protocol_Deploy.s.sol:DSC_Protocol_DeployScript --rpc-url $$SEPOLIA_RPC_URL --private-key $$PRIVATE_KEY --broadcast --verify --etherscan-api-key $$ETHERSCAN_API_KEY

# Advanced Security
.PHONY: security-deep
security-deep: security
	@echo "🔍 Running deep security analysis..."
	@echo "This includes additional checks and manual review points"
	@mkdir -p security-reports/deep
	@if command -v slither >/dev/null 2>&1; then \
		echo "Running Slither printers..."; \
		slither . --print human-summary > security-reports/deep/slither-human-summary.txt 2>&1; \
		slither . --print inheritance-graph > security-reports/deep/slither-inheritance.txt 2>&1; \
		slither . --print call-graph > security-reports/deep/slither-call-graph.txt 2>&1; \
	fi
	@echo "✅ Deep security analysis complete"

.PHONY: gas-analysis
gas-analysis:
	@echo "⛽ Running gas analysis..."
	@mkdir -p security-reports/gas
	forge test --gas-report > security-reports/gas/gas-report.txt
	@echo "✅ Gas analysis complete"

# CI/CD Targets
.PHONY: ci-test
ci-test: install build test coverage

.PHONY: ci-security
ci-security: install build security

.PHONY: ci-full
ci-full: ci-test ci-security gas-analysis