# Privacy

handoff-revive runs entirely on your machine. There is no server behind it,
no account, and no telemetry. The author of this plugin receives nothing —
not usage data, not error reports, not the contents of your handoffs.

## What it reads

| Source | What | Why |
|---|---|---|
| `git config user.name`, `user.email` | your name and email | written into the handoff so a teammate, or a later you, can see who saved it |
| the repository | branch, commit, changed file paths, commit subjects | to record where the work started from |
| failed tool calls | the command and its error text | so a resumed session reads what happened instead of recalling it |

## Where it goes

Everything is written to files under `.claude/handoff/` inside your project:
the handoff itself, snapshots of earlier saves, and a local record of failures.
That directory is listed in this project's `.gitignore`, so it is not committed
unless you choose to commit it.

Nothing leaves your machine unless you run `/handoff-revive:share-to-pr`. That
command posts the handoff as a comment on a pull request **you name**, through
the GitHub CLI (`gh`) using the credential `gh` already holds. The plugin never
reads, stores, or transmits that credential. The posted body is a sanitized
copy: the `author_email` line is removed, and absolute project and home paths
are replaced with placeholders.

## Turning parts of it off

| | Effect |
|---|---|
| `HANDOFF_HIDE_EMAIL=1` | the handoff records your name but not your email |
| `HANDOFF_EVIDENCE=off` | failed commands and their error text are not recorded |
| don't run `share-to-pr` | nothing is ever sent anywhere |

## Retention

The author operates no service, so there is nothing to retain. On your machine,
snapshots older than `HANDOFF_HISTORY_RETENTION_DAYS` (30 by default) are
deleted automatically, and you can delete `.claude/handoff/` at any time
without breaking anything.

## A caution about what you write

The handoff holds whatever the session puts in it, and a session working on
authentication or configuration can put a secret in a `done` line as easily as
anywhere else. `share-to-pr` strips paths and the email, and screens for common
secret shapes, but that screening is best-effort and cannot catch everything.
Read the body before you share it.
