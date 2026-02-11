#!/bin/bash
# test-files.sh — Tests for classify-file.sh
# Tests BLOCK and ASK file rules, plus safe files that should ALLOW.
#
# Usage: ./tests/test-files.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
CLASSIFY="$PLUGIN_ROOT/scripts/classify-file.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

run_classify() {
  local tool="$1"
  local file_path="$2"
  local content="${3:-test}"
  if [ "$tool" = "Write" ]; then
    jq -n --arg fp "$file_path" --arg c "$content" '{tool_name:"Write",tool_input:{file_path:$fp,content:$c}}' \
      | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$CLASSIFY" 2>/dev/null
  else
    jq -n --arg fp "$file_path" --arg c "$content" '{tool_name:"Edit",tool_input:{file_path:$fp,old_string:"old",new_string:$c}}' \
      | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$CLASSIFY" 2>/dev/null
  fi
}

test_block() {
  local file_path="$1"
  local desc="$2"
  local tool="${3:-Write}"
  local content="${4:-test}"
  ((TOTAL++))

  RESULT=$(run_classify "$tool" "$file_path" "$content")
  DECISION=$(echo "$RESULT" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)

  if [ "$DECISION" = "deny" ]; then
    ((PASS++))
  else
    echo -e "${RED}FAIL${NC} [BLOCK] $desc"
    echo "  File: $file_path"
    echo "  Expected: deny, Got: ${DECISION:-allow(empty)}"
    ((FAIL++))
  fi
}

test_ask() {
  local file_path="$1"
  local desc="$2"
  local tool="${3:-Write}"
  local content="${4:-test}"
  ((TOTAL++))

  RESULT=$(run_classify "$tool" "$file_path" "$content")
  DECISION=$(echo "$RESULT" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)

  if [ "$DECISION" = "ask" ]; then
    ((PASS++))
  else
    echo -e "${RED}FAIL${NC} [ASK] $desc"
    echo "  File: $file_path"
    echo "  Expected: ask, Got: ${DECISION:-allow(empty)}"
    ((FAIL++))
  fi
}

test_allow() {
  local file_path="$1"
  local desc="$2"
  local tool="${3:-Write}"
  local content="${4:-test}"
  ((TOTAL++))

  RESULT=$(run_classify "$tool" "$file_path" "$content")
  DECISION=$(echo "$RESULT" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)

  if [ -z "$DECISION" ]; then
    ((PASS++))
  else
    echo -e "${RED}FAIL${NC} [ALLOW] $desc"
    echo "  File: $file_path"
    echo "  Expected: allow(empty), Got: $DECISION"
    ((FAIL++))
  fi
}

echo "=========================================="
echo " SafeRun Guard — File Rules Tests"
echo "=========================================="
echo ""

# ============================================================
# 🔴 BLOCK — Credentials
# ============================================================
echo -e "${RED}--- BLOCK: Credentials ---${NC}"

test_block "/Users/art/project/.env" ".env"
test_block "/Users/art/project/.env.local" ".env.local"
test_block "/Users/art/project/.env.production" ".env.production"
test_block "/Users/art/.ssh/id_rsa" ".ssh/id_rsa"
test_block "/Users/art/.ssh/id_ed25519" ".ssh/id_ed25519"
test_block "/Users/art/.ssh/authorized_keys" ".ssh/authorized_keys"
test_block "/Users/art/.ssh/config" ".ssh/config"
test_block "/Users/art/project/server.pem" "server.pem"
test_block "/Users/art/project/private.key" "private.key"
test_block "/Users/art/project/cert.p12" "cert.p12"
test_block "/Users/art/project/keystore.jks" "keystore.jks"
test_block "/Users/art/.aws/credentials" ".aws/credentials"
test_block "/Users/art/.config/gcloud/application_default_credentials.json" "gcloud credentials"
test_block "/Users/art/.kube/config" ".kube/config"
test_block "/Users/art/.npmrc" ".npmrc"
test_block "/Users/art/.pypirc" ".pypirc"

# ============================================================
# 🔴 BLOCK — Git internals
# ============================================================
echo -e "${RED}--- BLOCK: Git internals ---${NC}"

test_block "/Users/art/project/.git/HEAD" ".git/HEAD"
test_block "/Users/art/project/.git/config" ".git/config"
test_block "/Users/art/project/.git/hooks/pre-commit" ".git/hooks/pre-commit"

# ============================================================
# 🔴 BLOCK — Shell config
# ============================================================
echo -e "${RED}--- BLOCK: Shell config ---${NC}"

test_block "/Users/art/.bashrc" ".bashrc"
test_block "/Users/art/.zshrc" ".zshrc"
test_block "/Users/art/.profile" ".profile"
test_block "/Users/art/.bash_profile" ".bash_profile"

# ============================================================
# 🔴 BLOCK — System paths
# ============================================================
echo -e "${RED}--- BLOCK: System paths ---${NC}"

test_block "/etc/hosts" "/etc/hosts"
test_block "/etc/passwd" "/etc/passwd"
test_block "/usr/local/bin/my-script" "/usr/local/bin"
test_block "/var/log/syslog" "/var/log"
test_block "/System/Library/something" "/System/"

# ============================================================
# 🔴 BLOCK — Lockfiles
# ============================================================
echo -e "${RED}--- BLOCK: Lockfiles ---${NC}"

test_block "/Users/art/project/package-lock.json" "package-lock.json"
test_block "/Users/art/project/yarn.lock" "yarn.lock"
test_block "/Users/art/project/pnpm-lock.yaml" "pnpm-lock.yaml"
test_block "/Users/art/project/Pipfile.lock" "Pipfile.lock"
test_block "/Users/art/project/poetry.lock" "poetry.lock"
test_block "/Users/art/project/composer.lock" "composer.lock"
test_block "/Users/art/project/Cargo.lock" "Cargo.lock"
test_block "/Users/art/project/Gemfile.lock" "Gemfile.lock"

# Also test with Edit tool
echo -e "${RED}--- BLOCK: Edit tool ---${NC}"

test_block "/Users/art/project/.env" ".env (Edit)" "Edit"
test_block "/Users/art/.ssh/id_rsa" ".ssh/id_rsa (Edit)" "Edit"
test_block "/etc/hosts" "/etc/hosts (Edit)" "Edit"

echo ""

# ============================================================
# 🟡 ASK — CI/CD
# ============================================================
echo -e "${YELLOW}--- ASK: CI/CD ---${NC}"

test_ask "/Users/art/project/.github/workflows/ci.yml" "GitHub Actions workflow"
test_ask "/Users/art/project/.github/workflows/deploy.yml" "GitHub Actions deploy"
test_ask "/Users/art/project/.gitlab-ci.yml" "GitLab CI"
test_ask "/Users/art/project/Jenkinsfile" "Jenkinsfile"

# ============================================================
# 🟡 ASK — Docker/Infra
# ============================================================
echo -e "${YELLOW}--- ASK: Docker/Infra ---${NC}"

test_ask "/Users/art/project/Dockerfile" "Dockerfile"
test_ask "/Users/art/project/docker-compose.yml" "docker-compose.yml"
test_ask "/Users/art/project/compose.yaml" "compose.yaml"
test_ask "/Users/art/project/infra/main.tf" "Terraform .tf"
test_ask "/Users/art/project/infra/vars.tfvars" "Terraform .tfvars"

# ============================================================
# 🟡 ASK — K8s manifests
# ============================================================
echo -e "${YELLOW}--- ASK: K8s manifests ---${NC}"

test_ask "/Users/art/project/k8s/deployment.yaml" "K8s deployment"
test_ask "/Users/art/project/k8s/service.yml" "K8s service"
test_ask "/Users/art/project/k8s/ingress.yaml" "K8s ingress"

# ============================================================
# 🟡 ASK — Database
# ============================================================
echo -e "${YELLOW}--- ASK: Database ---${NC}"

test_ask "/Users/art/project/schema.sql" "SQL file"
test_ask "/Users/art/project/db/migrations/001_init.py" "migration file"

# ============================================================
# 🟡 ASK — Deploy configs
# ============================================================
echo -e "${YELLOW}--- ASK: Deploy configs ---${NC}"

test_ask "/Users/art/project/Procfile" "Procfile"
test_ask "/Users/art/project/fly.toml" "fly.toml"
test_ask "/Users/art/project/vercel.json" "vercel.json"
test_ask "/Users/art/project/netlify.toml" "netlify.toml"
test_ask "/Users/art/project/CODEOWNERS" "CODEOWNERS"

# Also test with Edit tool
echo -e "${YELLOW}--- ASK: Edit tool ---${NC}"

test_ask "/Users/art/project/Dockerfile" "Dockerfile (Edit)" "Edit"
test_ask "/Users/art/project/.github/workflows/ci.yml" "workflow (Edit)" "Edit"

echo ""

# ============================================================
# 🔴 NEW BLOCK file rules
# ============================================================
echo -e "${RED}--- BLOCK: New credential files ---${NC}"

test_block "/Users/art/.docker/config.json" ".docker/config.json"
test_block "/Users/art/.netrc" ".netrc"
test_block "/Users/art/.gnupg/pubring.kbx" ".gnupg/ directory"
test_block "/Users/art/.gnupg/trustdb.gpg" ".gnupg/ trustdb"

echo ""

# ============================================================
# 🟡 NEW ASK file rules
# ============================================================
echo -e "${YELLOW}--- ASK: New infra/CI files ---${NC}"

test_ask "/Users/art/project/nginx.conf" "nginx.conf"
test_ask "/Users/art/project/.circleci/config.yml" ".circleci/config.yml"
test_ask "/Users/art/project/serverless.yml" "serverless.yml"
test_ask "/Users/art/project/serverless.yaml" "serverless.yaml"
test_ask "/Users/art/project/buildspec.yml" "buildspec.yml"
test_ask "/Users/art/project/cloudbuild.yaml" "cloudbuild.yaml"

echo ""

# ============================================================
# 🔐 CONTENT SCANNING tests
# ============================================================
echo -e "${YELLOW}--- Content Scanning: Secrets ---${NC}"

# AWS keys
test_ask "/Users/art/project/config.js" "AWS access key in content" "Write" "const key = 'AKIAIOSFODNN7EXAMPLE';"
test_ask "/Users/art/project/config.py" "AWS secret key in content" "Write" "aws_secret_access_key = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'"

# Private keys
test_ask "/Users/art/project/setup.sh" "private key in content" "Write" "-----BEGIN RSA PRIVATE KEY-----"
test_ask "/Users/art/project/cert.txt" "EC private key in content" "Write" "-----BEGIN EC PRIVATE KEY-----"

# GitHub tokens
test_ask "/Users/art/project/deploy.sh" "GitHub token in content" "Write" "export GITHUB_TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn"

# OpenAI/Stripe keys
test_ask "/Users/art/project/config.ts" "OpenAI key in content" "Write" "const apiKey = 'sk-abcdefghijklmnopqrstuvwxyz1234567890'"

# Slack tokens
test_ask "/Users/art/project/slack.js" "Slack token in content" "Write" "const token = 'xoxb-123456789-abcdef'"

# Connection strings
test_ask "/Users/art/project/db.py" "DB connection string in content" "Write" "DATABASE_URL=postgres://user:password123@host:5432/db"

# Safe content (no secrets)
test_allow "/Users/art/project/app.ts" "safe content" "Write" "console.log('hello world');"
test_allow "/Users/art/project/utils.py" "safe config content" "Write" "API_URL = 'https://api.example.com'"

echo ""

# ============================================================
# 🟢 ALLOW — Safe files
# ============================================================
echo -e "${GREEN}--- ALLOW: Safe files ---${NC}"

# Source code
test_allow "/Users/art/project/src/app.ts" "TypeScript"
test_allow "/Users/art/project/src/main.py" "Python"
test_allow "/Users/art/project/src/lib.rs" "Rust"
test_allow "/Users/art/project/src/App.jsx" "React JSX"
test_allow "/Users/art/project/src/index.js" "JavaScript"
test_allow "/Users/art/project/src/Main.java" "Java"
test_allow "/Users/art/project/src/main.go" "Go"

# Tests
test_allow "/Users/art/project/tests/test_app.py" "Python test"
test_allow "/Users/art/project/src/__tests__/app.test.ts" "TypeScript test"

# Docs
test_allow "/Users/art/project/README.md" "README.md"
test_allow "/Users/art/project/docs/guide.md" "docs markdown"
test_allow "/Users/art/project/CHANGELOG.md" "CHANGELOG"

# Project configs
test_allow "/Users/art/project/tsconfig.json" "tsconfig.json"
test_allow "/Users/art/project/.eslintrc.json" ".eslintrc"
test_allow "/Users/art/project/.prettierrc" ".prettierrc"
test_allow "/Users/art/project/package.json" "package.json"

# Static assets
test_allow "/Users/art/project/public/index.html" "HTML"
test_allow "/Users/art/project/src/styles.css" "CSS"

# Git meta (allowed, unlike .git/ internals)
test_allow "/Users/art/project/.gitignore" ".gitignore"
test_allow "/Users/art/project/.gitattributes" ".gitattributes"

echo ""

# ============================================================
# Results
# ============================================================
echo "=========================================="
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}ALL $TOTAL TESTS PASSED${NC}"
else
  echo -e "${RED}$FAIL/$TOTAL TESTS FAILED${NC} ($PASS passed)"
fi
echo "=========================================="

exit "$FAIL"
