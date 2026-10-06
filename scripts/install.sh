#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

if (( $# > 1 )); then
  echo "Usage: $0 [--skip-system-packages]" >&2
  exit 2
fi

case "${1:-}" in
  --help|-h)
    echo "Usage: $0 [--skip-system-packages]"
    echo "Install Ruby/build tools on Ubuntu or Debian, then the site's gems."
    echo "Use --skip-system-packages if Ruby, Bundler and build tools are already installed."
    exit 0
    ;;
  --skip-system-packages) ;;
  "")
    if ! command -v apt-get >/dev/null; then
      echo "Install Ruby, Bundler and native build tools, then run $0 --skip-system-packages." >&2
      exit 1
    fi
    elevate=()
    if (( EUID != 0 )); then
      elevate=(sudo)
    fi
    "${elevate[@]}" apt-get update
    "${elevate[@]}" apt-get install -y ruby-full bundler build-essential zlib1g-dev
    ;;
  *) echo "Unknown option: $1 (see --help)" >&2; exit 2 ;;
esac

if ! command -v ruby >/dev/null || ! command -v bundle >/dev/null; then
  echo "Ruby and Bundler must be on PATH before installing the site's gems." >&2
  exit 1
fi

# Gems and Bundler settings stay inside this checkout; sudo is only used for apt.
bundle config set --local path vendor/bundle
bundle install
echo "Installed. Run ./scripts/build.sh serve to preview at http://localhost:4000."
