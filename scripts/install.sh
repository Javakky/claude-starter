#!/usr/bin/env bash
# Claude Starter - Install Script
# Usage: curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash
#        curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash -s -- --version v1.0.0
#        curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash -s -- --no-workflows
set -euo pipefail

# === 設定 ===
REPO_OWNER="${REPO_OWNER:-Javakky}"
REPO_NAME="${REPO_NAME:-claude-starter}"
DEFAULT_BRANCH="master"
VERSION="${VERSION:-}"
NO_WORKFLOWS="${NO_WORKFLOWS:-false}"
NO_CLAUDE="${NO_CLAUDE:-false}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# === カラー出力 ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# === ヘルプ ===
show_help() {
    cat << EOF
Claude Starter - Install Script

Usage:
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/master/scripts/install.sh | bash
  # または
  ./install.sh [OPTIONS]

Options:
  --version, -v VERSION   特定のバージョン（タグ）を指定 (例: v1.0.0)
  --no-workflows          GitHub Workflows をインストールしない
  --no-claude             .claude/ ディレクトリをインストールしない
  --force, -f             既存ファイルを上書き
  --dry-run               実際にはファイルを作成しない（確認用）
  --help, -h              このヘルプを表示

Environment Variables:
  REPO_OWNER              リポジトリオーナー (default: Javakky)
  REPO_NAME               リポジトリ名 (default: claude-starter)
  VERSION                 バージョン指定
  NO_WORKFLOWS            "true" で workflows をスキップ
  NO_CLAUDE               "true" で .claude をスキップ
  FORCE                   "true" で上書き
  DRY_RUN                 "true" で dry-run

Examples:
  # 基本インストール
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/master/scripts/install.sh | bash

  # バージョン指定
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/master/scripts/install.sh | bash -s -- -v v1.0.0

  # Workflows のみインストール
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/master/scripts/install.sh | bash -s -- --no-claude

  # 強制上書き
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/master/scripts/install.sh | bash -s -- --force
EOF
}

# === 引数解析 ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version|-v)
                VERSION="$2"
                shift 2
                ;;
            --no-workflows)
                NO_WORKFLOWS="true"
                shift
                ;;
            --no-claude)
                NO_CLAUDE="true"
                shift
                ;;
            --force|-f)
                FORCE="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# === ユーティリティ関数 ===
get_ref() {
    if [[ -n "$VERSION" ]]; then
        echo "$VERSION"
    else
        echo "$DEFAULT_BRANCH"
    fi
}

get_raw_url() {
    local path="$1"
    local ref
    ref=$(get_ref)
    echo "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${ref}/${path}"
}

download_file() {
    local url="$1"
    local dest="$2"
    local dest_dir
    dest_dir=$(dirname "$dest")

    # 既存ファイルチェック
    if [[ -f "$dest" && "$FORCE" != "true" ]]; then
        warn "Skipping (already exists): $dest"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would download: $url -> $dest"
        return 0
    fi

    # ディレクトリ作成
    mkdir -p "$dest_dir"

    # ダウンロード
    if curl -sSfL "$url" -o "$dest" 2>/dev/null; then
        success "Downloaded: $dest"
    else
        error "Failed to download: $url"
        return 1
    fi
}

# === メイン処理 ===
install_claude_directory() {
    info "Installing .claude/ directory..."

    local files=(
        ".claude/commands/implement.md"
        ".claude/commands/fix_ci.md"
        ".claude/commands/review_prep.md"
        ".claude/commands/refactor_by_lint.md"
        ".claude/commands/orchestrator.md"
        ".claude/rules/00_scope.md"
        ".claude/rules/10_workflow.md"
        ".claude/rules/20_quality.md"
        ".claude/rules/30_security.md"
        ".claude/rules/40_output.md"
    )

    for file in "${files[@]}"; do
        download_file "$(get_raw_url "$file")" "$file"
    done
}

install_github_workflows() {
    info "Installing .github/ directory..."

    local files=(
        ".github/workflows/claude.yml"
        ".github/workflows/claude_review.yml"
        ".github/workflows/sync_templates.yml"
        ".github/pull_request_template.md"
        ".github/ISSUE_TEMPLATE/agent_task.md"
    )

    for file in "${files[@]}"; do
        download_file "$(get_raw_url "$file")" "$file"
    done
}

install_scripts_and_docs() {
    info "Installing scripts and docs..."

    local files=(
        "scripts/sync_templates.py"
        "docs/agent/TASK.md"
        "docs/agent/PR.md"
    )

    for file in "${files[@]}"; do
        download_file "$(get_raw_url "$file")" "$file"
    done
}

main() {
    parse_args "$@"

    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║     Claude Starter - Installer         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    local ref
    ref=$(get_ref)
    info "Repository: ${REPO_OWNER}/${REPO_NAME}"
    info "Reference: ${ref}"
    info "Force: ${FORCE}"
    info "Dry-run: ${DRY_RUN}"
    echo ""

    # インストール実行
    if [[ "$NO_CLAUDE" != "true" ]]; then
        install_claude_directory
    fi

    if [[ "$NO_WORKFLOWS" != "true" ]]; then
        install_github_workflows
    fi

    # scripts と docs は常にインストール
    install_scripts_and_docs

    echo ""
    success "Installation complete!"
    echo ""
    info "Next steps:"
    echo "  1. Add CLAUDE_CODE_OAUTH_TOKEN to your repository secrets"
    echo "  2. Customize .claude/rules/ for your project"
    echo "  3. Adjust .github/workflows/claude.yml for your language/framework"
    echo ""
    info "Documentation: https://github.com/${REPO_OWNER}/${REPO_NAME}"
}

main "$@"
