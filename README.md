# Max Tencesson's GitHub Pages

Simplified version of [Academic Pages](https://academicpages.github.io/)

## Local development

On Ubuntu or Debian (including Ubuntu in WSL), install Ruby, Bundler, build tools,
and the site's gems:

```bash
./scripts/install.sh
```

The script uses `sudo` for system packages. Gems are installed inside
`vendor/bundle`. If Ruby, Bundler, and build tools are already installed, use
`./scripts/install.sh --skip-system-packages` instead.

Preview changes without pushing to GitHub:

```bash
./scripts/build.sh serve
```

Open <http://localhost:4000>. Markdown and SCSS edits trigger a rebuild and browser
reload. Restart the server after changing `_config.yml`. Press Ctrl+C to stop.
To preview drafts or future-dated posts, use
`./scripts/build.sh serve --drafts --future`.

Build the production site into `_site` and check for build/front matter errors:

```bash
./scripts/build.sh
```

The Gemfile pins the [GitHub Pages dependency bundle](https://pages.github.com/versions/).
These commands follow [GitHub's local Jekyll preview workflow](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/testing-your-github-pages-site-locally-with-jekyll).

## Code highlighting

Choose a paired light/dark code-block palette in `_config.yml`:

```yaml
syntax_theme: github
```

Available values are `github` (the default when omitted) and `default` (the original
site palette). The existing sun/moon toggle switches between the selected palette's
light and dark colors. Restart the preview server after changing this setting.

GitHub colors are adapted from the [GitHub Light](https://github.com/highlightjs/highlight.js/blob/main/src/styles/github.css)
and [GitHub Dark](https://github.com/highlightjs/highlight.js/blob/main/src/styles/github-dark.css)
palettes to Rouge tokens, with a darker light-mode builtin orange for readability.
The GitHub preset includes its own code-block backgrounds and plain text colors;
inline code follows `site_theme`. The `default` preset uses the site theme's code
backgrounds and plain text colors.

To customize a preset, edit its light (`:root`) and dark (`html[data-theme="dark"]`)
variables in `_sass/syntax/_github.scss` or `_sass/syntax/_default.scss`.
To add another preset, create `_sass/syntax/_NAME.scss` with the same variables and
set `syntax_theme: NAME`. An unknown preset name causes a Sass import error at build time.
After editing, preview a post with fenced Python code in both modes; check comments,
keywords, strings, numbers, inline code, and scrolling for long lines.

## Search indexing workflow

`.github/workflows/search-indexing.yml` runs after each GitHub Pages build and can also be triggered manually.

Required setup:

- Google Search Console: set `GOOGLE_SERVICE_ACCOUNT` plus either `GOOGLE_WORKLOAD_IDENTITY_PROVIDER` or `GOOGLE_CREDENTIALS`. The service account must be added as an owner of the Search Console property for `https://tenecsson.github.io/`. If you use `GOOGLE_CREDENTIALS`, that service account also needs `roles/iam.serviceAccountTokenCreator` on itself so the workflow can mint an access token.
- IndexNow: set `INDEXNOW_KEY`. By default the workflow expects a public key file at `https://tenecsson.github.io/<INDEXNOW_KEY>.txt` whose contents are exactly the same key. If you host the key file somewhere else, also set `INDEXNOW_KEY_LOCATION`.

The workflow assumes `_config.yml` keeps `url: https://tenecsson.github.io` and `baseurl: ""`.
