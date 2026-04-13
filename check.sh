#!/usr/bin/env bash
# HW2 Submission Validator
# Run: bash check.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

errors=0
warnings=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((warnings++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((errors++)); }

echo ""
echo "═══════════════════════════════════════════"
echo "  CS292C HW2 Submission Checker"
echo "═══════════════════════════════════════════"
echo ""

# Check Python files exist and have been modified
echo "Code Files"
for f in p1_z3_warmup.py p2_vcgen.py p3_agent_policy.py p4_tool_chain.py p5_bonus.py; do
    if [ -f "$f" ]; then
        if grep -q "TODO" "$f"; then
            warn "$f exists but still has TODOs"
        else
            pass "$f — no remaining TODOs"
        fi
    else
        fail "$f not found"
    fi
done
echo ""

# Check writeup
echo "Writeup"
if [ -f "writeup.pdf" ]; then
    pass "writeup.pdf exists"
else
    fail "writeup.pdf not found (required for pen-and-paper problems)"
fi
echo ""

# Try running each file
echo "Execution Check"
for f in p1_z3_warmup.py p2_vcgen.py p3_agent_policy.py p4_tool_chain.py p5_bonus.py; do
    if [ -f "$f" ]; then
        if python3 "$f" > /dev/null 2>&1; then
            pass "$f runs without errors"
        else
            warn "$f has runtime errors (check your implementation)"
        fi
    fi
done
echo ""

# Check Z3 is installed
echo "Dependencies"
if python3 -c "from z3 import *" 2>/dev/null; then
    pass "z3-solver is installed"
else
    fail "z3-solver not found — run: pip install z3-solver"
fi
echo ""

# Summary
echo "═══════════════════════════════════════════"
if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo -e "  ${GREEN}All checks passed!${NC} Ready to submit."
elif [ "$errors" -eq 0 ]; then
    echo -e "  ${YELLOW}$warnings warning(s)${NC}, 0 errors. Review warnings above."
else
    echo -e "  ${RED}$errors error(s)${NC}, $warnings warning(s). Fix errors before submitting."
fi
echo "═══════════════════════════════════════════"
echo ""

exit $errors
