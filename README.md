# Max Tencesson's GitHub Pages

Simplified version of [Academic Pages](https://academicpages.github.io/)

## Search indexing workflow

`.github/workflows/search-indexing.yml` runs after each GitHub Pages build and can also be triggered manually.

Required setup:

- Google Search Console: set `GOOGLE_SERVICE_ACCOUNT` plus either `GOOGLE_WORKLOAD_IDENTITY_PROVIDER` or `GOOGLE_CREDENTIALS`. The service account must be added as an owner of the Search Console property for `https://tenecsson.github.io/`. If you use `GOOGLE_CREDENTIALS`, that service account also needs `roles/iam.serviceAccountTokenCreator` on itself so the workflow can mint an access token.
- IndexNow: set `INDEXNOW_KEY`. By default the workflow expects a public key file at `https://tenecsson.github.io/<INDEXNOW_KEY>.txt` whose contents are exactly the same key. If you host the key file somewhere else, also set `INDEXNOW_KEY_LOCATION`.

The workflow assumes `_config.yml` keeps `url: https://tenecsson.github.io` and `baseurl: ""`.
