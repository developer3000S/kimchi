#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo -e "${GREEN}🚀 Starting Kimchi dev environment setup...${NC}"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}⚠️  Homebrew not found. Please install Homebrew first:${NC}"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Check for node and pnpm (skip if already installed)
echo -e "${GREEN}📦 Checking node and pnpm...${NC}"

# Fix for corepack/undici failing with socks:// proxies
# Undici (used by Corepack) only supports http: and https: protocols for proxies.
PNPM_ENV=""
if [[ "$https_proxy" == socks://* || "$http_proxy" == socks://* || "$all_proxy" == socks://* || "$HTTPS_PROXY" == socks://* || "$HTTP_PROXY" == socks://* || "$ALL_PROXY" == socks://* ]]; then
    echo -e "${YELLOW}   ⚠️  Detected socks:// proxy which is unsupported by Node.js/Corepack. Unsetting for pnpm commands...${NC}"
    PNPM_ENV="env https_proxy= http_proxy= all_proxy= HTTPS_PROXY= HTTP_PROXY= ALL_PROXY="
fi

if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}   Installing node...${NC}"
    brew install node
else
    echo -e "${GREEN}   ✓ node already installed ($(node --version))${NC}"
fi

if ! command -v pnpm &> /dev/null; then
    echo -e "${YELLOW}   Installing pnpm...${NC}"
    brew install pnpm
else
    PNPM_VERSION=$($PNPM_ENV pnpm --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}   ✓ pnpm already installed ($PNPM_VERSION)${NC}"
fi

# Install dependencies
echo -e "${GREEN}📦 Installing dependencies with pnpm...${NC}"
$PNPM_ENV pnpm install

# Install bun if not present
echo -e "${GREEN}📦 Checking bun...${NC}"
BUN_JUST_INSTALLED=false
if ! command -v bun &> /dev/null; then
    echo -e "${YELLOW}   Installing bun...${NC}"
    curl -fsSL https://bun.sh/install | bash
    BUN_JUST_INSTALLED=true
else
    echo -e "${GREEN}   ✓ bun already installed ($(bun --version 2>/dev/null || echo "not working"))${NC}"
fi

# Always ensure bun is in PATH for this session
export PATH="$HOME/.bun/bin:$PATH"

# Verify bun works
USE_BUN=true
if ! bun --version &> /dev/null; then
    echo -e "${RED}❌ bun is installed but not working on this system (likely 'Illegal instruction: 4').${NC}"
    echo -e "${YELLOW}   Switching to 'tsx' as a fallback.${NC}"
    USE_BUN=false
fi

# Copy resources
echo -e "${GREEN}📂 Copying resources...${NC}"
node ./scripts/copy-resources.js --dev

# Start the harness
echo -e "${GREEN}🎯 Starting Kimchi harness...${NC}"
if [ "$USE_BUN" = true ]; then
    pnpm run dev "$@"
else
    pnpm run dev:node "$@"
fi

# Remind user to add bun to shell profile if it was just installed
if [ "$BUN_JUST_INSTALLED" = true ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Important: bun was just installed. To use it in future terminal sessions,${NC}"
    echo -e "${YELLOW}   add the following line to your shell profile:${NC}"
    echo ""
    echo -e "   ${GREEN}export PATH=\"\$HOME/.bun/bin:\$PATH\"${NC}"
    echo ""
    echo -e "   ${YELLOW}Shell profile locations:${NC}"
    echo -e "   • bash: ~/.bashrc or ~/.bash_profile"
    echo -e "   • zsh:  ~/.zshrc"
fi
