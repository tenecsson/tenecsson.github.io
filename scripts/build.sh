#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

mode="${1:-build}"
if (( $# > 0 )); then
  shift
fi
case "$mode" in
  build|serve) ;;
  --help|-h)
    echo "Usage: $0 [build|serve] [Jekyll options...]"
    echo "build (default): production build into _site."
    echo "serve: local preview with automatic rebuild and browser reload."
    echo "Example: $0 serve --drafts --future"
    exit 0
    ;;
  *) echo "Unknown mode: $mode (see --help)" >&2; exit 2 ;;
esac

if ! command -v bundle >/dev/null; then
  echo "Bundler is missing. Run ./scripts/install.sh first." >&2
  exit 1
fi
if ! bundle check; then
  echo "Dependencies are missing. Run ./scripts/install.sh first." >&2
  exit 1
fi

if [[ "$mode" == serve ]]; then
  # Jekyll serve replaces site.url with localhost, including the site's asset links.
  exec env JEKYLL_ENV=development bundle exec jekyll serve \
    --host localhost --port 4000 --baseurl "" --livereload --strict_front_matter "$@"
else
  exec env JEKYLL_ENV=production bundle exec jekyll build --strict_front_matter "$@"
fi
