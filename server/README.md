# Server setup (one time)

The pipeline uploads the built site over SSH with rsync, then runs `activate <commit sha>`. On the server, a dedicated key is pinned to [`deploy-gate.sh`](deploy-gate.sh), which only allows those two operations.

## Layout

The web server (`new_server`) serves `../wiki-dist/current` relative to its working directory, i.e. a `wiki-dist` directory next to `site/` and `aventuros-spas/`:

```text
wiki-dist/
├── staging/          # rsync target (the only place the deploy key can write)
├── releases/<sha>/   # immutable snapshots, hard-linked from staging
└── current -> releases/<sha>
```

The last 5 releases are kept (`KEEP_RELEASES`). To roll back, repoint the symlink: `ln -sfn releases/<old sha> current.tmp && mv -T current.tmp current`.

## Steps

1. Install the tools: `sudo apt install rsync` (provides `/usr/bin/rrsync` on Debian 12+; otherwise copy it from `/usr/share/doc/rsync/scripts/`). `flock` comes from `util-linux`.

2. Create a deploy user and the directory tree. The `new_server` process must be able to read it:

    ```sh
    sudo useradd --system --create-home --shell /bin/bash deploy
    sudo mkdir -p "<path>/wiki-dist/staging" "<path>/wiki-dist/releases"
    sudo chown -R deploy: "<path>/wiki-dist"
    ```

3. Install the gate and set `WIKI_ROOT` in it to the absolute path of `wiki-dist`:

    ```sh
    sudo install -o root -g root -m 755 deploy-gate.sh /home/deploy/deploy-gate.sh
    sudo sed -i 's|^WIKI_ROOT=.*|WIKI_ROOT="<path>/wiki-dist"|' /home/deploy/deploy-gate.sh
    ```

4. Generate a key pair just for this (on any machine) and authorize it with the forced command:

    ```sh
    ssh-keygen -t ed25519 -N '' -C github-wiki-deploy -f wiki_deploy
    ```

    Add this line to `/home/deploy/.ssh/authorized_keys` (mode 600, owned by `deploy`):

    ```text
    command="/home/deploy/deploy-gate.sh",restrict ssh-ed25519 AAAA... github-wiki-deploy
    ```

5. Add the repository secrets (Settings → Secrets and variables → Actions), and create the `production` environment (Settings → Environments) if you want manual approval before deploys:

    | Secret | Value |
    | ------ | ----- |
    | `DEPLOY_HOST` | server hostname or IP |
    | `DEPLOY_PORT` | SSH port (defaults to 22 if empty) |
    | `DEPLOY_USER` | `deploy` |
    | `DEPLOY_SSH_KEY` | contents of `wiki_deploy` (the private key), then delete the local file |
    | `DEPLOY_KNOWN_HOSTS` | output of `ssh-keyscan -p <port> <host>`, checked against the server's real host keys |

6. Make sure GitHub-hosted runners can reach the SSH port: their IPs change and are not in any allowlist, so check that the IP ban list or fail2ban will not block them. If the port must stay firewalled, use a self-hosted runner instead.

## Checking it

From a machine holding the private key:

```sh
ssh -i wiki_deploy deploy@<host> ls          # must print "command not allowed"
ssh -i wiki_deploy deploy@<host> "activate $(printf 'a%.0s' {1..40})"   # fails: staging/index.html missing on first run
```
