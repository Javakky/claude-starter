#!/usr/bin/env bash
# Claude Starter - Update Script
# 既にインストールされた Claude Starter を最新版に更新するスクリプト
# Usage: ./scripts/update.sh
#        ./scripts/update.sh --version v1.0.0
set -euo pipefail

# === 設定 ===
REPO_OWNER="${REPO_OWNER:-Javakky}"
REPO_NAME="${REPO_NAME:-claude-starter}"
DEFAULT_BRANCH="master"
VERSION="${VERSION:-}"
BACKUP="${BACKUP:-true}"
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
Claude Starter - Update Script

Usage:
  ./scripts/update.sh [OPTIONS]

Options:
  --version, -v VERSION   特定のバージョン（タグ）を指定
  --no-backup             バックアップを作成しない
  --dry-run               実際にはファイルを更新しない（確認用）
  --help, -h              このヘルプを表示

Environment Variables:
  REPO_OWNER              リポジトリオーナー (default: Javakky)
  REPO_NAME               リポジトリ名 (default: claude-starter)
  VERSION                 バージョン指定
  BACKUP                  "false" でバックアップをスキップ
  DRY_RUN                 "true" で dry-run

Examples:
  # 最新版に更新
  ./scripts/update.sh

  # 特定バージョンに更新
  ./scripts/update.sh -v v1.0.0

  # バックアップなしで更新
  ./scripts/update.sh --no-backup
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
            --no-backup)
                BACKUP="false"
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

backup_file() {
    local file="$1"
    if [[ -f "$file" && "$BACKUP" == "true" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        if [[ "$DRY_RUN" == "true" ]]; then
            info "[DRY-RUN] Would backup: $file -> $backup"
        else
            cp "$file" "$backup"
            info "Backed up: $file -> $backup"
        fi
    fi
}

download_file() {
    local url="$1"
    local dest="$2"
    local dest_dir
    dest_dir=$(dirname "$dest")

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would download: $url -> $dest"
        return 0
    fi

    # ディレクトリ作成
    mkdir -p "$dest_dir"

    # バックアップ
    backup_file "$dest"

    # ダウンロード
    if curl -sSfL "$url" -o "$dest" 2>/dev/null; then
        success "Updated: $dest"
    else
        error "Failed to download: $url"
        return 1
    fi
}

# === カスタマイズ検出 ===
# ユーザーがカスタマイズした可能性のあるファイルを検出
detect_customizations() {
    info "Checking for customizations..."

    local customized_files=()

    # .claude/rules/ はカスタマイズされている可能性が高い
    if [[ -d ".claude/rules" ]]; then
        for file in .claude/rules/*.md; do
            if [[ -f "$file" ]]; then
                # ファイルの内容を確認してデフォルトと異なるか判定
                # ここでは単純に存在確認のみ
                customized_files+=("$file")
            fi
        done
    fi

    # .github/workflows/claude.yml も言語固有の設定がある
    if [[ -f ".github/workflows/claude.yml" ]]; then
        customized_files+=(".github/workflows/claude.yml")
    fi

    if [[ ${#customized_files[@]} -gt 0 ]]; then
        warn "The following files may contain customizations:"
        for file in "${customized_files[@]}"; do
            echo "  - $file"
        done
        echo ""
        warn "These files will be backed up before updating."
    fi
}

# === メイン処理 ===
update_safe_files() {
    # カスタマイズされにくいファイル（常に最新を取得しても問題ないもの）
    info "Updating safe files..."

    local files=(
        ".claude/commands/implement.md"
        ".claude/commands/fix_ci.md"
        ".claude/commands/review_prep.md"
        ".claude/commands/refactor_by_lint.md"
        ".claude/commands/orchestrator.md"
        "scripts/sync_templates.py"
        "scripts/install.sh"
        "scripts/update.sh"
        ".github/workflows/sync_templates.yml"
    )

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            download_file "$(get_raw_url "$file")" "$file"
        else
            info "Skipping (not installed): $file"
        fi
    done
}

update_customizable_files() {
    # カスタマイズされている可能性のあるファイル
    info "Updating customizable files (with backup)..."

    local files=(
        ".claude/rules/00_scope.md"
        ".claude/rules/10_workflow.md"
        ".claude/rules/20_quality.md"
        ".claude/rules/30_security.md"
        ".claude/rules/40_output.md"
        ".github/workflows/claude.yml"
        ".github/workflows/claude_review.yml"
        ".github/pull_request_template.md"
        ".github/ISSUE_TEMPLATE/agent_task.md"
        "docs/agent/TASK.md"
        "docs/agent/PR.md"
    )

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            download_file "$(get_raw_url "$file")" "$file"
        else
            info "Skipping (not installed): $file"
        fi
    done
}

main() {
    parse_args "$@"

    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║     Claude Starter - Updater           ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    local ref
    ref=$(get_ref)
    info "Repository: ${REPO_OWNER}/${REPO_NAME}"
    info "Reference: ${ref}"
    info "Backup: ${BACKUP}"
    info "Dry-run: ${DRY_RUN}"
    echo ""

    # カスタマイズ検出
    detect_customizations

    # 更新実行
    update_safe_files
    update_customizable_files

    echo ""
    success "Update complete!"

    if [[ "$BACKUP" == "true" ]]; then
        echo ""
        info "Backups were created with .backup.YYYYMMDD_HHMMSS suffix"
        info "Review changes and delete backups when satisfied:"
        echo "  find . -name '*.backup.*' -type f"
    fi
}

main "$@"
