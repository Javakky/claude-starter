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
Claude Starter - Update Script

Usage:
  ./scripts/update.sh [OPTIONS]

Options:
  --version, -v VERSION   特定のバージョン（タグ）を指定
  --dir, -d DIRECTORY     更新先ディレクトリ (default: .)
  --no-backup             バックアップを作成しない
  --dry-run               実際にはファイルを更新しない（確認用）
  --help, -h              このヘルプを表示

Environment Variables:
  REPO_OWNER              リポジトリオーナー (default: Javakky)
  REPO_NAME               リポジトリ名 (default: claude-starter)
  VERSION                 バージョン指定
  TARGET_DIR              更新先ディレクトリ (default: .)
  BACKUP                  "false" でバックアップをスキップ
  DRY_RUN                 "true" で dry-run

Examples:
  # 最新版に更新
  ./scripts/update.sh

  # 特定バージョンに更新（推奨：タグ指定で供給元改変の影響を避ける）
  ./scripts/update.sh -v v1.0.0

  # バックアップなしで更新
  ./scripts/update.sh --no-backup

  # dry-run で確認（推奨：実行前に確認）
  ./scripts/update.sh --dry-run
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

# 真偽値の判定ヘルパー（true/1/yes/y/on を true として扱う）
is_true() {
    case "${1,,}" in
        true|1|yes|y|on) return 0 ;;
        *) return 1 ;;
    esac
}

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
# GET で必須ファイルを取得し、存在しなければエラー（HEAD より確実）
validate_ref() {
    local ref
    ref=$(get_ref)
    local test_url
    # README.md ではなく、このスクリプトが必要とするファイルで検証
    test_url="$(get_raw_url "scripts/sync_templates.py")"

    info "Validating reference '${ref}'..."
    if ! curl -fsSL "$test_url" -o /dev/null 2>&1; then
        error "Reference '${ref}' does not exist or is not accessible"
        error "Please check if the version/branch name is correct"
        exit 1
    fi
}

# TARGET_DIR の検証
validate_target_dir() {
    local abs
    # cd && pwd で正規化（相対パス、.、.. すべて対応）
    abs="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
        error "Target directory '$TARGET_DIR' does not exist"
        exit 1
    }
    TARGET_DIR="$abs"

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

backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && is_true "$BACKUP"; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        if is_true "$DRY_RUN"; then
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

    if is_true "$DRY_RUN"; then
        info "[DRY-RUN] Would download: $url -> $dest"
        return 0
    fi

    # 親ディレクトリがファイルとして存在する場合はエラー
    local parent="$dest_dir"
    while [[ "$parent" != "/" && "$parent" != "." ]]; do
        if [[ -f "$parent" ]]; then
            error "Cannot create directory '$dest_dir': '$parent' is a file"
            return 1
        fi
        parent=$(dirname "$parent")
    done

    # ディレクトリ作成
    mkdir -p "$dest_dir"

    # バックアップ
    backup_file "$dest"

    # ダウンロード（エラー出力を表示）
    if curl -fsSL "$url" -o "$dest"; then
        success "Updated: $dest"
    else
        error "Failed to download: $url"
        return 1
    fi
}

# === ファイル一覧（1箇所で管理） ===
declare -a SAFE_FILES=(
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

declare -a CUSTOMIZABLE_FILES=(
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

# === カスタマイズ検出 ===
# ユーザーがカスタマイズした可能性のあるファイルを検出
detect_customizations() {
    info "Checking for customizations..."

    local customized_files=()

    # .claude/rules/ はカスタマイズされている可能性が高い
    if [[ -d "${TARGET_DIR}/.claude/rules" ]]; then
        for file in "${TARGET_DIR}"/.claude/rules/*.md; do
            if [[ -f "$file" ]]; then
                # ファイルの内容を確認してデフォルトと異なるか判定
                # ここでは単純に存在確認のみ
                customized_files+=("$file")
            fi
        done
    fi

    # .github/workflows/claude.yml も言語固有の設定がある
    if [[ -f "${TARGET_DIR}/.github/workflows/claude.yml" ]]; then
        customized_files+=("${TARGET_DIR}/.github/workflows/claude.yml")
    fi

    if [[ ${#customized_files[@]} -gt 0 ]]; then
        warn "The following files may contain customizations:"
        for file in "${customized_files[@]}"; do
            printf "  - %s\n" "$file"
        done
        printf "\n"
        warn "These files will be backed up before updating."
    fi
}

# === メイン処理 ===
update_safe_files() {
    # カスタマイズされにくいファイル（常に最新を取得しても問題ないもの）
    info "Updating safe files..."

    for file in "${SAFE_FILES[@]}"; do
        local dest="${TARGET_DIR}/${file}"
        if [[ -f "$dest" ]]; then
            download_file "$(get_raw_url "$file")" "$dest"
        else
            info "Skipping (not installed): $file"
        fi
    done
}

update_customizable_files() {
    # カスタマイズされている可能性のあるファイル
    info "Updating customizable files (with backup)..."

    for file in "${CUSTOMIZABLE_FILES[@]}"; do
        local dest="${TARGET_DIR}/${file}"
        if [[ -f "$dest" ]]; then
            download_file "$(get_raw_url "$file")" "$dest"
        else
            info "Skipping (not installed): $file"
        fi
    done
}

main() {
    parse_args "$@"

    printf "\n"
    printf "╔════════════════════════════════════════╗\n"
    printf "║     Claude Starter - Updater           ║\n"
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
    info "Backup: ${BACKUP}"
    info "Dry-run: ${DRY_RUN}"
    printf "\n"

    # カスタマイズ検出
    detect_customizations

    # 更新実行
    update_safe_files
    update_customizable_files

    printf "\n"
    success "Update complete!"

    if is_true "$BACKUP"; then
        printf "\n"
        info "Backups were created with .backup.YYYYMMDD_HHMMSS suffix"
        info "Review changes and delete backups when satisfied:"
        printf "  find . -name '*.backup.*' -type f\n"
    fi
}

main "$@"
