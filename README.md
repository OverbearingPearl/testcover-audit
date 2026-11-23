# ci-elisp

A check suite and pipeline for Emacs Lisp packages. It is vendored into a
project as the directory `ci/` and never edited there: a fix lands here, the
projects pull it.

## Add it to a project

Once, in a project that has no `ci/` yet:

```sh
git subtree add --prefix=ci git@github.com:OverbearingPearl/ci-elisp.git main --squash \
  && ci/bootstrap.sh
```

After that, updating is the pull and then bootstrap:

```sh
git subtree pull --prefix=ci git@github.com:OverbearingPearl/ci-elisp.git main --squash
ci/bootstrap.sh
```

Bootstrap writes the project's files, installs the git hooks when it is the one
that wrote their config, and runs a first `make lint`, saying either that the
package is clean or which message is the first to fix. Hooks are a question of
ownership rather than of what is installed: a project that already has
`.pre-commit-config.yaml` or hooks in `.git/hooks` keeps them and bootstrap only
says so; `--force` takes them over. The three hooks it writes are the message
check, lint and tests. `pre-commit` itself is never installed -- without it the
hooks are written but not installed, and the script says which command to run.
The line is two commands joined, not a downloader: nothing is fetched but the
subtree.

If the project already has a `Makefile` or a `.github/`, bootstrap keeps them
and says what is missing from them: the targets the hooks call, and the
workflows the templates would have provided. `--force` replaces a file, which
is worth reading twice for `.github/`: it deletes every workflow already
there.

A `.gitignore` is written only when the project has none. An existing one is
kept even under `--force`, because it usually lists paths ci knows nothing
about; the template's `.cache/` and `build/` entries have to be added by hand
to an older file.

`ci/bootstrap.sh --help` is the whole usage, and it ends with the four things
the project owns from then on.

## Update a project

The two commands from the section above. The squash commit names the upstream
commit, which is the pin, and `git subtree pull` refuses a dirty tree.

Bootstrap is what tells you whether anything you own has moved: it compares each
file it wrote with the template and says `same as the template` or how many
lines differ.

To take one template file after a pull — a Makefile that gained a target, say —
copy that file:

```sh
cp ci/templates/Makefile Makefile        # one file, not all of them
```

`ci/bootstrap.sh --force` replaces every file it wrote, and for `.github/` it
deletes everything there, including the jobs you added. Reach for it only in a
project that has never customised those files.


## What you own, and what a pull replaces

| half | lives in | pulled |
| --- | --- | --- |
| checks, scripts, benchmarks, the size and coverage reports | `ci/` | yes |
| policy: Emacs versions, directories, budgets, size, coverage | `config/ci.el` | no |
| a benchmark of this package's own hot path | `config/perf.el` | no |
| a definition count for `make size` | `config/size.el` | no |
| vendored packages | `vendor/` | no, the project's own |
| workflows, actions, `Makefile`, `.gitignore`, hook config | `.github/`, root files | no, written once |

Editing anything under `ci/` conflicts with the next pull. Everything else is
yours.

Two checks are repository-shaped rather than file-shaped.  `adr-format`
validates the records in `docs/decisions/` -- the directory and the naming are
fixed, the body may be Nygard or MADR -- and it does nothing when a project
keeps no records.  `layer-order` enforces the arrows between module layers and
is off until a project declares them in `config/ci.el`.  Both are described in
[MANUAL.md](MANUAL.md).

## Read on

| Document | Answers |
| --- | --- |
| [MANUAL.md](MANUAL.md) | what each check does, the policy tables, the CI pipeline, MELPA |
| `ci/bootstrap.sh --help` | the knobs a project has, at the moment it runs |
| a project's `config/ci.el` | the knobs, with the defaults commented next to them |
