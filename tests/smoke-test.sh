#!/usr/bin/env sh
# =============================================================================
# smoke-test.sh
# Reusable HTTP health-check smoke test for post-deployment verification.
#
# Usage:
#   sh tests/smoke-test.sh <URL> [MAX_RETRIES] [RETRY_DELAY_SECONDS]
#
# Examples:
#   sh tests/smoke-test.sh https://api.example.com/health
#   sh tests/smoke-test.sh https://api.example.com/health 8 20
#
# Exit codes:
#   0  — Health check passed (HTTP 200)
#   1  — All retries exhausted; health check failed
# =============================================================================

set -e

HEALTH_URL="${1:?ERROR: URL argument required. Usage: sh smoke-test.sh <URL> [retries] [delay]}"
MAX_RETRIES="${2:-5}"
RETRY_DELAY="${3:-15}"

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

separator() {
  printf '%s\n' "──────────────────────────────────────────────────────────────"
}

separator
printf "${CYAN}${BOLD}🧪 SMOKE TEST${RESET}\n"
printf "  URL:         %s\n" "$HEALTH_URL"
printf "  Max Retries: %s\n" "$MAX_RETRIES"
printf "  Retry Delay: %ss\n" "$RETRY_DELAY"
separator

attempt=1
while [ "$attempt" -le "$MAX_RETRIES" ]; do
  printf "${YELLOW}[Attempt %d/%d]${RESET} Checking %s ...\n" \
    "$attempt" "$MAX_RETRIES" "$HEALTH_URL"

  # Capture HTTP status code, follow redirects, 30s connect timeout, 60s max
  HTTP_STATUS=$(
    curl --silent \
         --output /dev/null \
         --write-out "%{http_code}" \
         --location \
         --connect-timeout 30 \
         --max-time 60 \
         "$HEALTH_URL" 2>/dev/null
  ) || HTTP_STATUS="000"

  printf "  → HTTP Status: %s\n" "$HTTP_STATUS"

  if [ "$HTTP_STATUS" = "200" ]; then
    separator
    printf "${GREEN}${BOLD}✅ Smoke test PASSED${RESET} (HTTP %s after %d attempt(s))\n" \
      "$HTTP_STATUS" "$attempt"
    separator
    exit 0
  fi

  if [ "$attempt" -lt "$MAX_RETRIES" ]; then
    printf "  → Not ready yet. Waiting %ss before retry...\n\n" "$RETRY_DELAY"
    sleep "$RETRY_DELAY"
  fi

  attempt=$((attempt + 1))
done

separator
printf "${RED}${BOLD}❌ Smoke test FAILED${RESET} — HTTP %s after %d attempts.\n" \
  "$HTTP_STATUS" "$MAX_RETRIES"
printf "  Action required: Check application logs and consider rollback.\n"
separator
exit 1
