# sakura-config

Clash configuration and an AdGuard search filter.

## Clash

Configuration: `sakura`. Custom rules: `rules/`.

Use [jsDelivr Purge](https://www.jsdelivr.com/tools/purge) to refresh:

```text
https://cdn.jsdelivr.net/gh/sea-with-sakura/sakura-config@main/sakura
```

## AdGuard

Hide selected paper aggregation sites from desktop Google, Bing, and Baidu results.

Add this URL as a custom filter in AdGuard:

```text
https://raw.githubusercontent.com/sea-with-sakura/sakura-config/main/paper-search-subscription/paper-search-filter.txt
```

Requires AdGuard Extended CSS support. Not compatible with AdGuard Home or DNS filtering.

To update, edit [`domains.txt`](paper-search-subscription/domains.txt) and push to `main`. GitHub Actions generates and commits the filter automatically. Enable Actions and allow workflow write access in the repository settings.

Use one domain or path per line, for example `example.com` or `example.org/papers/`. For an optional local build on Windows, run `paper-search-subscription/build.cmd`.
