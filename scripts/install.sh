#!/usr/bin/env bash
# Claude Starter - Install Script
# Usage: curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/main/scripts/install.sh | bash
#        curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/main/scripts/install.sh | bash -s -- --version v1.0.0
#        curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/main/scripts/install.sh | bash -s -- --no-workflows
set -euo pipefail

# === 設定 ===
REPO_OWNER="${REPO_OWNER:-Javakky}"
REPO_NAME="${REPO_NAME:-claude-starter}"
DEFAULT_BRANCH="main"
VERSION="${VERSION:-}"
NO_WORKFLOWS="${NO_WORKFLOWS:-false}"
NO_CLAUDE="${NO_CLAUDE:-false}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
TARGET_DIR="${TARGET_DIR:-.}"

# === カラー出力 ===
# TTY 判定でカラー ON/OFF
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    NC=""
fi

info()    { printf "%b\n" "${BLUE}[INFO]${NC} $*"; }
success() { printf "%b\n" "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { printf "%b\n" "${YELLOW}[WARN]${NC} $*"; }
error()   { printf "%b\n" "${RED}[ERROR]${NC} $*" >&2; }

# === ヘルプ ===
show_help() {
    cat << EOF
Claude Starter - Install Script

Usage:
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${DEFAULT_BRANCH}/scripts/install.sh | bash
  # または
  ./install.sh [OPTIONS]

Options:
  --version, -v VERSION   特定のバージョン（タグ）を指定 (例: v1.0.0)
  --dir, -d DIRECTORY     インストール先ディレクトリ (default: .)
  --no-workflows          GitHub Workflows をインストールしない
  --no-claude             .claude/ ディレクトリをインストールしない
  --force, -f             既存ファイルを上書き
  --dry-run               実際にはファイルを作成しない（確認用）
  --help, -h              このヘルプを表示

Environment Variables:
  REPO_OWNER              リポジトリオーナー (default: Javakky)
  REPO_NAME               リポジトリ名 (default: claude-starter)
  VERSION                 バージョン指定
  TARGET_DIR              インストール先ディレクトリ (default: .)
  NO_WORKFLOWS            "true" で workflows をスキップ
  NO_CLAUDE               "true" で .claude をスキップ
  FORCE                   "true" で上書き
  DRY_RUN                 "true" で dry-run

Examples:
  # 基本インストール
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${DEFAULT_BRANCH}/scripts/install.sh | bash

  # バージョン指定（推奨：タグ指定で供給元改変の影響を避ける）
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${DEFAULT_BRANCH}/scripts/install.sh | bash -s -- -v v1.0.0

  # インストール先を指定
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${DEFAULT_BRANCH}/scripts/install.sh | bash -s -- --dir /path/to/project

  # Workflows のみインストール
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${DEFAULT_BRANCH}/scripts/install.sh | bash -s -- --no-claude

  # 強制上書き
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${DEFAULT_BRANCH}/scripts/install.sh | bash -s -- --force

  # dry-run で確認（推奨：実行前に確認）
  curl -sL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${DEFAULT_BRANCH}/scripts/install.sh | bash -s -- --dry-run
EOF
}

# === 引数解析 ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version|-v)
                if [[ $# -lt 2 || -z "${2:-}" || "$2" == --* ]]; then
                    error "--version requires a value (e.g., -v v1.0.0)"
                    exit 1
                fi
                VERSION="$2"
                shift 2
                ;;
            --dir|-d)
                if [[ $# -lt 2 || -z "${2:-}" || "$2" == --* ]]; then
                    error "--dir requires a value (e.g., --dir /path/to/project)"
                    exit 1
                fi
                TARGET_DIR="$2"
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

# バージョン形式の検証
validate_version() {
    local version="$1"
    if [[ -n "$version" && ! "$version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z0-9]+)?$ ]]; then
        warn "Version '$version' does not match expected format (e.g., v1.0.0)"
        warn "Proceeding anyway - this may be a branch name or commit SHA"
    fi
}

get_ref() {
    if [[ -n "$VERSION" ]]; then
        validate_version "$VERSION"
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

# ref（タグ/ブランチ）が存在するか事前検証
validate_ref() {
    local ref
    ref=$(get_ref)
    local test_url="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${ref}/README.md"

    info "Validating reference '${ref}'..."
    if ! curl -fsSL --head "$test_url" >/dev/null 2>&1; then
        error "Reference '${ref}' does not exist or is not accessible"
        error "Please check if the version/branch name is correct"
        exit 1
    fi
}

# TARGET_DIR の検証
validate_target_dir() {
    # 絶対パスに変換
    if [[ "$TARGET_DIR" != /* ]]; then
        TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
            error "Target directory '$TARGET_DIR' does not exist"
            exit 1
        }
    fi

    # ディレクトリであることを確認
    if [[ ! -d "$TARGET_DIR" ]]; then
        error "Target '$TARGET_DIR' is not a directory"
        exit 1
    fi

    # .git の存在確認（警告のみ）
    if [[ ! -d "$TARGET_DIR/.git" ]]; then
        warn "Target directory does not appear to be a Git repository"
        warn "Make sure you are running this in the correct directory"
    fi
}

download_file() {
    local url="$1"
    local dest="$2"
    local dest_dir
    dest_dir=$(dirname "$dest")

    # 既存ファイル/ディレクトリチェック
    if [[ -e "$dest" && "$FORCE" != "true" ]]; then
        if [[ -d "$dest" ]]; then
            warn "Skipping (directory exists at path): $dest"
        else
            warn "Skipping (already exists): $dest"
        fi
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would download: $url -> $dest"
        return 0
    fi

    # ディレクトリ作成
    mkdir -p "$dest_dir"

    # ダウンロード（エラー出力を表示）
    if curl -fsSL "$url" -o "$dest"; then
        success "Downloaded: $dest"
    else
        error "Failed to download: $url"
        return 1
    fi
}

# === ファイル一覧（1箇所で管理） ===
declare -a CLAUDE_FILES=(
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

declare -a WORKFLOW_FILES=(
    ".github/workflows/claude.yml"
    ".github/workflows/claude_review.yml"
    ".github/workflows/sync_templates.yml"
    ".github/pull_request_template.md"
    ".github/ISSUE_TEMPLATE/agent_task.md"
)

declare -a SCRIPTS_AND_DOCS_FILES=(
    "scripts/sync_templates.py"
    "docs/agent/TASK.md"
    "docs/agent/PR.md"
)

# === メイン処理 ===
install_claude_directory() {
    info "Installing .claude/ directory..."

    for file in "${CLAUDE_FILES[@]}"; do
        download_file "$(get_raw_url "$file")" "${TARGET_DIR}/${file}"
    done
}

install_github_workflows() {
    info "Installing .github/ directory..."

    for file in "${WORKFLOW_FILES[@]}"; do
        download_file "$(get_raw_url "$file")" "${TARGET_DIR}/${file}"
    done
}

install_scripts_and_docs() {
    info "Installing scripts and docs..."

    for file in "${SCRIPTS_AND_DOCS_FILES[@]}"; do
        download_file "$(get_raw_url "$file")" "${TARGET_DIR}/${file}"
    done
}

main() {
    parse_args "$@"

    printf "\n"
    printf "╔════════════════════════════════════════╗\n"
    printf "║     Claude Starter - Installer         ║\n"
    printf "╚════════════════════════════════════════╝\n"
    printf "\n"

    # 事前検証
    validate_target_dir
    validate_ref

    local ref
    ref=$(get_ref)
    info "Repository: ${REPO_OWNER}/${REPO_NAME}"
    info "Reference: ${ref}"
    info "Target: ${TARGET_DIR}"
    info "Force: ${FORCE}"
    info "Dry-run: ${DRY_RUN}"
    printf "\n"

    # インストール実行
    if [[ "$NO_CLAUDE" != "true" ]]; then
        install_claude_directory
    fi

    if [[ "$NO_WORKFLOWS" != "true" ]]; then
        install_github_workflows
    fi

    # scripts と docs は常にインストール
    install_scripts_and_docs

    printf "\n"
    success "Installation complete!"
    printf "\n"
    info "Next steps:"
    printf "  1. Add CLAUDE_CODE_OAUTH_TOKEN to your repository secrets\n"
    printf "  2. Customize .claude/rules/ for your project\n"
    printf "  3. Adjust .github/workflows/claude.yml for your language/framework\n"
    printf "\n"
    info "Documentation: https://github.com/${REPO_OWNER}/${REPO_NAME}"
}

main "$@"
