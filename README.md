# LintPal GitHub Action

Run [LintPal](https://github.com/diffpal/lintpal) against committed pull-request
changes, publish a deterministic gate result and inline rule findings, and keep
the findings v5 artifact. LintPal uses Jev for typed rule decisions; it does not
generate a semantic code review or change summary.

```yaml
name: lintpal
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

jobs:
  lint:
    if: ${{ !github.event.pull_request.draft && github.event.pull_request.head.repo.full_name == github.repository }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v6
        with:
          node-version: 24
      - uses: diffpal/lintpal-action@v1
        with:
          lintpal-version: "0.4.0"
          base: ${{ github.event.pull_request.base.sha }}
          head: ${{ github.event.pull_request.head.sha }}
          block-on: high
          gate: true
        env:
          TYPESAFE_API_KEY: ${{ secrets.TYPESAFE_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: lintpal-findings
          path: .artifacts/lintpal/
          if-no-files-found: warn
```

The default provider is `jev`, which reads `TYPESAFE_API_KEY`. `openrouter`
reads `OPENROUTER_API_KEY`; `custom` reads the environment variable named by
`auth-token-env`. Token values are never Action inputs. Keep the same-repository
guard when a provider secret is present; fork code must not receive it.

Required inputs are `base` and `head`. Other inputs are `install`,
`lintpal-version`, `lintpal-path`, `provider`, `model`, `rules`, `include`,
`exclude`, `block-on`, `gate`, `report-path`, `review-channel`, `repo`,
`pr-number`, `timeout`, `max-concurrency`, `base-url`, and `auth-token-env`.
The `report-path` output names the retained artifact. Include/exclude values are
newline-delimited and are passed as separate arguments without shell evaluation.

The Action runs `lintpal lint --block-on` first and publishes the completed
artifact with `lintpal feedback github` second. Operational lint failures stop
before publication. Exit 10 is returned only after publication when `gate` is
enabled. Pin `lintpal-version` for reproducible workflows.

- [Rule catalog](https://github.com/diffpal/lintpal-rules)
- [Demo repository](https://github.com/diffpal/lintpal-demo)

MIT licensed.
