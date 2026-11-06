# Wiki Aventuros

Source of [wiki.aventuros.fr](https://wiki.aventuros.fr/). Pages are Markdown files in [`docs/`](docs/), built into a static site with [Zensical](https://zensical.org/), configured in [`zensical.toml`](zensical.toml).

## Writing pages

- Add a `.md` file under `docs/`. The folder structure becomes the navigation, and `docs/foo/bar.md` is served at `/foo/bar/`.
- Link to other pages by their file path (`[texte](../foo/bar.md)`), not by URL: the build checks that every link and anchor exists.
- Admonitions (`!!! note`), collapsible blocks (`??? warning`), tables and fenced code are available. See [`docs/exemple/page.md`](docs/exemple/page.md).

## Previewing locally

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/zensical serve        # http://127.0.0.1:8000, reloads on save
```

Run the same checks as CI before pushing:

```sh
.venv/bin/pymarkdown --config .pymarkdown.json scan -r docs
.venv/bin/zensical build --strict
```

## Pipeline

[`.github/workflows/wiki.yml`](.github/workflows/wiki.yml) runs two jobs:

- **build**, on every push and pull request: it lints the Markdown with PyMarkdown, builds with `zensical build --strict` (broken links and anchors fail the build), and uploads the site as an artifact.
- **deploy**, only on pushes to `master` after build succeeds: it rsyncs the site to the server's staging directory over SSH, then activates it as a new release by atomically swapping a symlink.

Server-side setup and the required secrets are described in [`server/README.md`](server/README.md).
