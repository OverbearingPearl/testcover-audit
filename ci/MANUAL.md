# The suite in detail

## Layout the policy assumes

```
<pkg>.el            the package entry point, the only .el at the repo root
lisp/<pkg>-*.el     business modules; the package prefix is required
test/*-tests.el     test modules; the package prefix is forbidden
vendor/**/*.el      vendored packages, not ours to restyle
```

The root directory holds exactly one `.el` file; anything else is a
violation with a clear message rather than a file that silently escapes
the checks.  The main file does not have to be named after the repository:
it is discovered, not assumed -- and its base name *is* the package name.

## Naming

Three strings have to agree, and the suite checks the two adjacent pairs
rather than the transitive one:

| string | example | the rule |
|---|---|---|
| package name | `pkg` | it is the main module's name, by definition |
| module name | `pkg-loop`, `loop-tests` | starts with `<pkg>-` under `lisp/`, and nowhere else |
| definition name | `pkg-loop-step`, `loop-tests-step` | carries the module's full name |

`module-prefix` answers the first pair, per class: required in `lisp/`
because those modules are published, forbidden in `test/` and `ci/` because
they are not, and repeating the package name in every test file name is
noise.  `definition-prefix` answers the second pair: the prefix is the
whole module name, not just the package name, so a definition says which
module a failure came from.  `test-suffix` adds the one suffix rule:
`test/` modules end in `-tests`.

Nothing compares a definition with the package name directly, and nothing
needs to: the package prefix is on the module name (`module-prefix`) and
the module name is on the definition (`definition-prefix`).

`vendor/` is exempt from all three.  It carries somebody else's package
prefix, and its file names and definitions are not ours to change.  The
tooling under `ci/` is exempt from `definition-prefix` for a related
reason: it is shared code that must not name the package at all
(`project-neutral`), so its definitions use the suite's own prefix.

A project that is itself one of the suite's dependencies is the one case
`project-neutral` cannot answer.  `ci/coverage.el` has to name
testcover-audit and `ci/deps.el` has to name testcover-audit and
package-lint, so the mention the rule forbids and the dependency the
suite installs are the same string.  The check does not run for such a
project, because no edit could make it pass.

A business module needs a name after the prefix: `lisp/<pkg>-.el` and
`lisp/<pkg>--name.el` both fail, because the module name would be empty or
start with a dash.  Inside any module, `defcustom`, `defvar`, `defun`,
macros, aliases, ERT tests, structs, classes and generics follow the same
rule, and a mode also ends in `-mode`.  `cl-defmethod` is left out: its
name belongs to the generic it extends, which may not be ours.

### The main module

The package name is read from the main file -- `p/package-name` is its base
name -- so the main module and the package are the same string and there
is nothing to compare.  The one naming exception sits here: the main
module may define an entry command named exactly `<pkg>`, because that is
what users type.

### Test modules

A test module is not published, so the package prefix is forbidden there;
its name is free in every other way, but its definitions are prefixed with
the module name like anywhere else (`loop-tests-...`).  The `-tests` suffix
is required, and it earns its place twice: MELPA's default file spec
excludes `*-tests.el`, so tests never reach a published tarball, and the
suffix marks a file as a test without opening it.

A test is also the only place where a name may appear before it exists. The
first step of a TDD cycle is a test that calls a function nobody has written
yet, and `banned-construct' forbids `declare-function', the other way to say
"this will exist at runtime", so the compiler has to be told not to mind.
Two checks relax for `test/`:

| relaxed for `test/` | why |
|---|---|
| `package-lint` | it models a published package; its prefix rule would ask for the package prefix |
| `byte-compile`: `lexical` | the "dynamic var lacks a prefix" warning is a convention for published code |
| `byte-compile`: `unresolved` | a test names the API before it is written; a mistyped name still fails when ERT runs it |

Everything else still applies: whitespace, heading comments, banned
constructs, byte-compilation, checkdoc, header rules, `provide` matching the
file name, dependency direction.

### One header list, three views

`ci/config.el` spells the package headers once:

```elisp
:package-headers ("Copyright" "Author" "Assisted-by" "URL" "Version"
                  "SPDX-License-Identifier" "Package-Requires" "Keywords")
:header-sets ((:package    :all)
              (:submodule  (:but "Version" "Package-Requires" "Keywords"))
              (:entry-only (:only "Version" "Package-Requires" "Keywords")))
```

`:package` is the whole list, `:submodule` is that list minus the headers
only an entry point declares, and `:entry-only` is exactly those three.  The
profiles then say:

| class | rule |
|---|---|
| `main` | `(:require :package)` |
| `business` | `(:require :submodule :forbid :entry-only)` |
| `test`, `tooling` | `(:forbid :package)` |

So a submodule cannot declare a version, its own dependencies or keywords
(`Package-Requires` outside the main file has no effect anyway), and a file
that is not the package carries no package header at all.

### Commentary length depends on the class

The `:commentary` slot of each class profile sets `:min` and `:max`
descriptive lines: 2 or more for published modules, 1 to 3 for tests, 1 or
more for tooling.  Published modules have to carry their weight; a test
file says what it exercises in a line or two, and a long Commentary on a
test module is itself the smell.

## Whitespace, and the one rule with no upstream

Three rules are about a file's shape rather than its content:

| rule | wants |
|---|---|
| `text-hygiene` | no trailing whitespace, exactly one final newline, every tracked or untracked text file outside `vendor/` |
| `blank-lines` | at most one consecutive blank line |
| `commentary-width` | lines inside `;;; Commentary` fit `:commentary-width` columns as displayed, not as characters |

`heading-comment` asks that a `;;;` heading be surrounded by blank lines,
which is the one part of this that the Emacs Lisp manual already says.

The blank line rule is the exception, and it stays fixed.  "At most one" is
nobody's standard -- two blank lines between top-level forms is ordinary
Emacs Lisp, and Emacs's own sources do it -- but the number is not a setting
either.  A number a project may change is not a rule, and a rule that is real
has to be written down as one rather than hidden behind a key that exists
only to be left alone.  This tree keeps one blank line, a copy that disagrees
deletes the check, and neither side pretends the other's taste is the
convention.

## Scope

Two tables, one axis each, and nothing else:

| axis | where | answers |
|---|---|---|
| per check | `:classes (...)` in the check's own file | which kinds of file this rule applies to |
| per class | `:profiles` in `ci/config.el` | what a file of that kind must be: headers, allowed requires, Commentary length |

A file's class comes from its directory (`main` = the single `.el` at the
root, `business` = `lisp/`, `test` = `test/`, `tooling` = `ci/`), decided
by `p/module-class` in `ci/lib/project.el`.  The join is one `memq` inside
`p/defcheck` in `ci/lib/registry.el`, and that is the only place class
dispatch happens.

The current profiles:

```
main      headers (:require :package)                          may require business            commentary 2-
business  headers (:require :submodule, :forbid :entry-only)   may require business            commentary 2-
test      headers (:forbid  :package)   may require main business test vendor  commentary 1-3
tooling   headers (:forbid  :package)   may require tooling             commentary 1-
vendor    headers none                  may require vendor              commentary 0-
```

Reading a row answers "what is a test file" in one line.  And these two
views are generated, not maintained by hand:

```sh
ci/run-checks.sh --list                  # check x class matrix
ci/run-checks.sh --explain FILE          # one file: its class, its profile, every check
ci/run-checks.sh --files                 # every file the suite inspects, with its class
```

Both come from the registry and the policy, so neither can drift, and neither
is committed: a file that repeats what a command prints is a file that goes
stale on the one pull nobody re-ran it.  `policy` validates the tables
themselves: every class has a
profile with all three properties, every class named exists, every header
set resolves, and every class a check claims exists.  A misspelled class
would otherwise disable a rule silently.

## Decision records

A project that keeps architecture decision records gets two rules, and both
come from the `pi` extension that puts the record index into an agent's system
prompt: the directory is `docs/decisions`, and a record is
`NNNN-kebab-title.md` with four digits and no prefix.

Neither is a preference. The extension matches `^[0-9]{4}-` in that one
directory, so a record somewhere else, or a name with an `ADR-` prefix, is a
record it cannot see -- and a decision the agent cannot see vetoes nothing.
Both are reported, and `doc/adr`, `docs/adr`, `docs/adrs` and `adr` are named
as the shapes of the mistake. A project with no such directory has no records
and no rules.

What a record *says* is a separate question. Two content shapes are accepted,
because two are in the wild and both are readable:

- **MADR.** YAML front matter with at least `status` and a date, a title
  heading, then `Context and Problem Statement`, `Decision Outcome` and
  `Consequences` (the plain `Context`, `Decision` and `Considered Options`
  spellings pass too).
- **Nygard.** A numbered heading, a `Date: YYYY-MM-DD` line, `## Status`, then
  `## Context`, `## Decision` and `## Consequences`.

A file is asked to be one of them rather than a mixture. Headings may be level
one or two, since section names carry the meaning and templates disagree about
level. MADR constrains content only -- no directory, no file name -- so
accepting it costs the naming rule nothing.

Whichever shape a record takes, two parts are required and neither is in MADR's
or Nygard's minimum: a section naming the routes that were not taken, and a
line beginning `Cost:` in the consequences. A record without them reads as
notes about a decision -- the author knew the answer, so the alternatives and
the price are what they skipped writing down.

`decisions.md` is the table of contents a recording tool writes, and `0000-*`
is a template; neither is checked. Numbers are unique across the directory and
`superseded/`, because the number is the reference a later record uses. A
record whose status says superseded belongs in `superseded/`, and one in
`superseded/` has to say `superseded` and nothing else. The two words are not
interchangeable: `amended by` means the record is still in force with a later
record growing it, so an amended record stays where the index reads it.

## Vendored code

A directory of third-party files is a class of its own, because the rules for
our source are wrong for somebody else's: the headers belong to its author,
the Commentary is not ours to shorten, and its file names carry its package
prefix rather than ours.  That last fact is why the naming checks skip the
class entirely.

| key | default | what it decides |
|---|---|---|
| `:vendor-dir` | `"vendor"` | where vendored packages live |

Vendored files are discovered, classified as `vendor`, and put on the load
path, so a test can `require` them exactly as it requires the package. No
per-file check runs on them: the checks that ask about our own source run on
`main`, `business`, `test` and `tooling`, and a check that wants vendor files
names the class itself. `text-hygiene` skips the directory too -- whitespace
in a copy is the copy's business, and fixing it would put the file at odds
with the release it came from. The profile exists so the policy can answer
for the class -- no header is required or forbidden, the Commentary minimum
is zero, and a vendored module may only require another vendored one.

That last rule is the one rule that reaches vendor, and it is the useful one:
it keeps a vendored package from quietly depending on the host's modules,
which is how a copy stops being replaceable.

## Test dependencies

A test may need a package the package itself does not: a testing macro, a
fixture library.  Those are named in `:test-packages`, a list where each name
is both the archive package and the feature to require.

| key | default | what it decides |
|---|---|---|
| `:test-packages` | nil | packages the tests require, installed before ERT runs |

`make test` installs them into the project cache before the test modules load,
and `make lint` and `make coverage` do the same, so the compiler sees the
macros the way the test run does.  The project cache is used even when the
same package sits in the user's `~/.emacs.d/elpa`, because a stale global copy
would decide what the suite compiles against; a test dependency that depended
on who ran `make` first would make the CI's green meaningless.  Nothing here
belongs in `Package-Requires`: a user of the package does not need a testing
macro.

The alternative is `vendor/`; prefer the published package when there is one,
and vendor only what nobody publishes.

## Module layers

An architecture with layers has one rule a `require` can express, and the
class profiles cannot: every module in `lisp/` is class `business`, so nothing
in `:profiles` stops one business module from requiring another that sits
above it.

| key | default | what it decides |
|---|---|---|
| `:layers` | nil | layer name -> the module names in it, top of the stack first |
| `:layer-may-require` | nil | layer name -> the layers it may require, for a shape that is not a stack |

The module name is the file name without the package prefix (`module-prefix`
already guarantees that shape), so `loop` answers for `lisp/<pkg>-loop.el`.

The order of `:layers` is the direction: a layer may require itself and every
layer listed above it. A stack therefore needs one table, not two.

```elisp
(setq p/config
      (plist-put p/config :layers
                 '((core contract loop session)
                   (adapters provider-sse session-jsonl)
                   (product console tools undo))))
```

`:layer-may-require` is for the case the order cannot express -- two layers
at the same depth that may not see each other -- and wins over it when set.

A business module that is missing from `:layers` is reported rather than
exempted, because an undeclared module is the one a reviewer forgets to
place.  Nil disables the check.

## Stubs, and the map that outlives its modules

A project that writes its tests before its code needs a stand-in for each
function the stories call. The usual one is a map of names to a placeholder
that only defines a function which is not already defined, and it rots in
silence: once the module lands, the placeholder is harmless, the story passes
against the real code, and nothing says the entry is still there.

A project can name such a map, and then a stubbed name that a module now
defines is reported:

```elisp
:stubs (:file "test/support-tests.el"
        :form support-tests--stub
        :sources ("lisp"))
```

`:file` is the map, `:form` is the placeholder call, and `:sources` are the
directories holding real definitions -- `:submodule-dir` when it is left out.
The map itself is never read as a source, because the map defines every name
it lists.

A project with no `:stubs` key has no stubs and no rule.

## Layers


```
ci/                  what "correct" means          (runs anywhere, no GitHub)
ci/config.el         the only file with policy
ci/lib/              shared plumbing (no policy)
ci/checks/NN-*.el    one check per file, name = check name
ci/perf.el           the performance benchmarks (budgets live in config.el)
ci/size.el           what a module costs and repeats (policy in config.el)
ci/run-*.sh          the entry points make calls: checks, tests, perf, size

.github/actions/     one composite action per stage
.github/workflows/   ci, perf, melpa and release: stage orchestration only
```

A check is added by creating `ci/checks/NN-<name>.el` and calling
`p/defcheck` (per file) or `p/defcheck-global` (whole repository). There is
no central list to update: files are loaded in name order, and
`ci/run-checks.sh --list` prints what was registered, which is the table a
README would otherwise duplicate and get wrong.

## When what runs

Placement is chosen by what a failure means, not by how important the check is.
A gate that can fail for reasons the author cannot control teaches people to
reach for `--no-verify`, and that one habit costs more than any check it skips.

| gate | pre-commit | pre-push | CI on push and pull request | nightly | on demand |
|---|---|---|---|---|---|
| `make lint` | yes | | yes | | |
| `make test` | | yes | yes | | |
| `make perf-check` | | | | yes | yes |
| `make perf` | | | yes, uploaded as an artifact | | |
| `make size` | | | yes, uploaded as an artifact | | |
| `make coverage` | | | yes, uploaded as an artifact | | |
| melpazoid | | | | | yes |
| `make dist`, version tag | | | | | tag |

- **Fast, deterministic and offline goes into the commit gate.** `make lint`
  is under a second once the dependencies are cached, so it runs before every
  commit. The test suite sits at pre-push rather than pre-commit on purpose: it
  is a second today and will not be once it starts real processes, and a slow
  gate is a skipped gate.
- **Timing never gates a commit and never fails a pull request.** The same
  budget moves by an order of magnitude between a quiet machine and a busy one.
  The nightly run enforces it, where a failure is a mail rather than a blocked
  merge; pull requests get the table as an artifact, which is worth reading and
  not worth arguing with.
- **Anything that needs the outside world is on demand.** melpazoid builds a
  container that compiles Emacs from source; it belongs before a release or a
  MELPA pull request, not on every push. Trigger it with *Run workflow* on CI
  and tick `melpazoid`, or `gh workflow run ci.yml -f melpazoid=true`.

Two stages run on a schedule rather than on an event, and they are the two
kinds of schedule there are. The nightly perf run enforces the budgets, failing
into the same mail as everything else. The daily MELPA check is the opposite:
it exists to send one mail the day the recipe appears, and to be silent on
every other day. A tag runs lint, the version check, `make dist` and the
release.

## Emacs versions

CI runs the Emacs that `ubuntu-latest` ships, the same way melpazoid's own
workflow does. The floor is the Emacs the *suite* runs on, `:emacs-versions` in
`ci/config.el`, and it is a property of the suite rather than a knob: a project
has nothing to set. Two checks read it.

| check | question it answers |
|---|---|
| `emacs-version-minimum` | is the running Emacs at or above the floor? |
| `package-requires-emacs` | does the package promise at least that Emacs? |

The second one is the interesting one. A package that declares `((emacs "27.1"))`
is promising support for a version the suite has never linted and the project
has probably never run. The check reports the package's number against the
suite's, and the fix is either to raise the header or to say why the claim is
real.

A project that genuinely needs a different floor changes it in `ci/config.el`,
which is a deliberate departure from the shared suite rather than a setting.

## melpazoid, zero tolerance

`WARN_IS_ERROR=1` turns melpazoid's `:Warning:` lines into failures, and the
`with [melpazoid]` section is printed only when melpazoid has suggestions and
never changes the exit code, so it is gated with a log assertion:

| reported as | caught by |
|---|---|
| `:Error:` / `: error:` | exit code |
| `:Warning:` / `: warning:` | exit code, only with `WARN_IS_ERROR=1` |
| `━ ... with [melpazoid]` suggestions | `grep -qF 'with [melpazoid]'` |

`EXIST_OK` enables the package-name collision check, which asks whether the
name is still free.  That question expires: the day the recipe is merged the
name is taken, by this package, and the check starts reporting a clash with
itself.  So the action answers it instead of a human — `exist-ok: auto`, the
default, looks for `recipes/<pkg>` in `melpa/melpa` and skips the check only
when the 404 disappears.  A probe that fails for any reason other than 404
is an error rather than a quiet `false`, because guessing "not published"
from a timeout would turn the check back on without anyone noticing.  The
recipe and the name both come from `ci/config-export.sh package`, so no
package name appears in the workflow.

### Why it runs on demand, not on every push

Everything in this file so far costs seconds, which is why every push runs
it. melpazoid does not, and the reason is one line of its Dockerfile:

```dockerfile
RUN ... curl .../emacs-31.1.tar.gz | tar -xz && ./configure ... && make -j2 install
```

It compiles Emacs from source inside the image. On a two-core runner that is
the whole job — tens of minutes, reported by docker as a single line — and
the container then runs checkdoc, package-lint and byte-compile, which are
the first three checks of `make lint`. For a package with no MELPA
dependencies, which is this one, the container adds a second Emacs version
and little else.

What melpazoid adds that the suite cannot is MELPA's own review: the recipe
built by package-build, the checklist, the license check, the package name.
That is worth reading before a MELPA pull request or a release, not on
every push. So the stage is manual:

```
Actions -> CI -> Run workflow -> melpazoid (checkbox)
```

When it was blocking on every event it never actually ran to completion:
the CI concurrency group cancels the previous run on the next push, so any
commit inside the compile killed it and nothing was ever reported. A
manual run is slower than a cached one but it finishes, and it costs
nothing on the pushes you do not ask about.

Three things make that half hour legible. `DOCKER_OUTPUT='--quiet'` is
rewritten to `--progress=plain`, so docker reports one line per step rather
than one for the build. melpazoid's own notes are unbuffered
(`PYTHONUNBUFFERED=1`) and flow through `sed -u`, because a plain `sed`
block-buffers a pipe and the log looks frozen. And the step ends with how
long the run took. The compile step itself is silent for the bulk of the
wait; the step timer is the only sign of life, which is why this is a run
you start deliberately.

There is no image cache. `docker save`/`docker load` restores the image, not
BuildKit's build cache, so the next `docker build` recompiles everything
anyway, and the tarball would cost hundreds of megabytes of the cache
budget that `.cache/elpa` already uses. The patch that would make the image
cheap — replacing the Emacs build with `apt-get install emacs-nox` — is ten
lines and works, but it makes CI responsible for someone else's Dockerfile
and lints with a different Emacs than upstream intends. Half an hour of
manual runs is the cheaper mistake.

## MELPA's page is the status

There is no weekly job, and there was one: it mailed the download count and
the build status every Sunday. Both facts are printed on the package's MELPA
page, which the badge beside a README already links, and a cron job that
re-renders a web page into an email is a second copy of something that has an
owner.

What survives is the probe, `.github/actions/melpa-status`, because one
decision still needs it: melpazoid's `exist-ok` input asks whether
`melpa/melpa` has the recipe, and with the input at `auto` the answer decides
whether the name-collision check runs. That is a question a build asks, not a
question a schedule answers.

The status is read from
`melpa.org/download_counts.json`.  The two answer different questions: the
recipe appears when the pull request is merged, while the download counts
only know about packages someone has installed — a package published an hour
ago is missing from that file, which is not the same as unpublished.  The
counts are fetched separately, and a published package with no downloads yet
is reported as exactly that, not as zero.

Only `404` means "not yet".  Network failures fail the run and reach
`notify-failure` like every other stage; otherwise a broken probe looks
exactly like an unpublished package.

## Announcing it once

The page is the status, which leaves a schedule one thing to do: notice the
transition.  `.github/workflows/melpa.yml` asks `melpa-status` once a day and
then does nothing unless the recipe exists.  A package that is not on MELPA yet
is in the state it was in yesterday, and a mail about it would report nothing.

The mail goes out once, because "it is published" is an event, and a repeating
version of it is the weekly report that was deleted.  The record of having said
so is the tag `melpa-published`: the announcement looks for it, mails only when
it is missing, and writes it after handing the mail to `send-mail`.  A tag
rather than a file committed to the default branch, because the job has no
business committing, and rather than a repository variable, which is invisible
exactly where people look and cannot be reset by deleting something.

Order matters.  `send-mail` treats an SMTP outage as noise and carries on, so a
tag written first could stand for a mail that never left.  Written last, the
worst case is a second copy the next day -- a duplicate is a smaller mistake
than silence.

With `SMTP_HOST` unset nothing is sent *and nothing is tagged*: a fork, or a
project that never configured mail, would otherwise burn the record and lose
the announcement it stands for.  This is also the only job that asks for
`contents: write`, because pushing that tag is the only write in the suite.  On
a repository whose default token is read-only the push fails and reaches
`notify-failure` like any other stage; a silent downgrade would mean a mail
every day.

## Notification mail

Both kinds of mail carry two parts: a plain-text body with the same facts, for
terminals and mailboxes that are grepped rather than read, and an HTML card
for clients that render it.  The cards share a skeleton — rounded card,
coloured header, white body, grey footer — and the header colour is the
message: red for a failure, green for the one good thing that can happen to a
package.  That is the one thing worth scanning a subject line for.

No images and one colour each, so a client that strips styles down to text
loses nothing.  Logs are deliberately kept out of the HTML: they are in the
text part and in `failure-report.txt`, and pasting arbitrary log lines into
a document means either escaping them or occasionally sending mail that
renders as garbage from the first `<` onward.

Every fact in the card is a link.  A failure mail opens the run, the branch
and the commit.  The test is that nothing in
the inbox needs a search afterwards -- a notification earns its place by
saving the trip, not by reporting the news.

Nothing project-specific is written into `.github/`.  The package name comes
from `ci/config-export.sh package`; the repository, ref, commit, job, run
number and workflow name come from the `github` context; MELPA's URL layout
is written down once in `melpa-status`, which hands the page and recipe URLs
out as outputs.  That is what makes the directory copyable -- drop it into
another Emacs Lisp package and the mails name that package with no edit.

The skeleton lives in `mail-card` because two cards use it, and the frame is
the part that would drift first: a radius changed in one and not the other is
the kind of difference nobody notices until a mail looks broken.  The body
stays with the caller, because the failure card's table is not the
announcement's, and a renderer that took rows as data would have to escape
every value to be safe -- a promise these cards do not need, since every value
in them comes from a step in this directory.

`notify-failure` remains the only thing that assembles a failure report, and
six jobs still call it.

## pre-commit is local-only, on purpose

`.pre-commit-config.yaml` declares three hooks, all local: `make lint` at the
commit stage, `ci/check-commit-message.sh` at the commit-msg stage and
`make test` at the push stage. Each hook names its stage, and none is left
to default: a hook without a `stages` key belongs to every stage pre-commit
knows, and git calls two of them on a commit, so an undeclared `checks` runs
the whole lint twice before the message is even read. There is no remote hook
repository, so `pre-commit run --all-files` needs no network, builds no
virtualenv and starts instantly. That is the point of a local gate: it has to
work on a plane.

Both stages have to be installed, or the second one silently never runs:

```sh
make hooks          # installs all three
```

or, by hand: `pre-commit install`, then `--hook-type commit-msg` and
`--hook-type pre-push`.

`pre-commit run --all-files` runs the commit stage only; add
`--hook-stage pre-push` to exercise the other one without pushing.

The message hook enforces a fixed shape, because the alternative was worse:
once the hook reads its rules from configuration, changing one line means
tracing a plist through an export script into shell. The shape is the one
`ci/check-commit-message.sh` writes down -- capital subject, no type prefix,
80/72 columns -- and the prose rules live beside it in the project's own
`.pi/ai-git-commit.json`, which no script reads.

That file is prose for whoever drafts the message: what was wrong, what was
considered, why this shape. Bootstrap copies it from
`ci/templates/ai-git-commit.json` and keeps it afterwards, on the same terms
as the hook config. It has to sit at the repository root, because the program
drafting the message reads it there and knows nothing about `ci/`; the copy
the subtree brings along as `ci/.pi/ai-git-commit.json` is the suite's own
config and nobody reads it. The suite's copy is a symlink to the template, so
the wording here and the wording it hands out cannot drift.

So a project whose messages follow different rules does one of two things,
both of which the ownership rule above makes safe. It defines its own hooks,
in which case bootstrap never touches them; or it edits the
`.pre-commit-config.yaml` bootstrap wrote, which is a project file from then on
and is never rewritten.

Who owns the hooks decides what bootstrap does, and it asks two questions:

| the project already has | bootstrap does |
|---|---|
| `pre-commit` not on PATH | writes the config, installs nothing, says which command to run |
| `.pre-commit-config.yaml` | keeps it, installs nothing, points at `make hooks` |
| hooks in `.git/hooks` but no config | keeps them, writes no config, installs nothing |
| neither | writes the config, installs all three hooks with `make hooks` |

`--force` answers "take ci's hooks" for the two middle rows. It does not make
`pre-commit` appear; without the tool the config is a file that nothing runs.

## What --force will not replace

Two files are written once and are the project's from then on: the `Makefile`
and `config/ci.el`. `--force` skips them even when it was asked to overwrite
everything, because both are the sort of file whose loss is silent -- a
replaced `Makefile` stops running the project's own audit without saying so,
and a replaced `config/ci.el` takes the layer table with it.

`.gitignore` is stricter still: bootstrap writes the template only when the
project has none. A project's ignore file usually predates ci and lists paths
ci knows nothing about, so an existing one is kept even under `--force`. The
template ignores `.cache/` and `build/` because the lint job creates both; an
older project that keeps its own file has to add those two lines by hand.

A target of the project's own therefore does not belong in the `Makefile` at
all. It goes in `config/targets.mk`, which the template includes: a target
declared there, and the line `lint: <target>`, wire it into `make lint`
without editing the shared file. `help-extra` is the same for the help text.

The rest is replaceable on purpose: `.pre-commit-config.yaml`, `.github/` and
`.pi/ai-git-commit.json` are copies of ci's templates, and a project that
edited them has decided to own that copy -- the `kept` message names the file
and how far it differs.

`--force` refuses to replace a file that has uncommitted changes, and says
which command keeps a copy. Replacing it would leave the diff against `HEAD`
as the only record of what was lost, and a copy is cheaper than a diff somebody
has to read afterwards to find out.

A run that wrote something ends by printing what it wrote: the paths from
`git status --short`, a `git diff --stat` of their size, and the command that
shows the rest. It is short on purpose -- five lines a reader finishes -- and
a run that wrote nothing says nothing, because silence then means exactly one
thing.

The script itself enforces only what a script can see: a capitalised subject
with no type prefix and no trailing period, 80/72 columns, no marketing words,
no "Generated with" and no co-author trailer. It cannot see whether the change
is one change or whether the body explains why, which is where the rules spend
most of their words.

The hygiene checks that usually come from `pre-commit-hooks` are part of the
suite instead, so local and CI enforce the same code:

| used to be | now |
|---|---|
| `trailing-whitespace` | `text-hygiene`, for every tracked or untracked text file outside `vendor/` |
| `end-of-file-fixer` | `text-hygiene` (exactly one final newline, same files) |
| `check-yaml` | not in the gate; see below |

YAML syntax is not gated locally: Emacs has no YAML parser, and adding Ruby
or PyYAML would reintroduce exactly the dependency this section removes.
GitHub validates workflow and action files when it loads them, and a broken
one is loud. If you want it locally anyway, run it yourself:

```sh
ruby -ryaml -e 'Dir[".github/**/*.yml"].each { |f| YAML.load_file(f, aliases: true) }'
```

## Performance budgets

`make perf-check` measures the handful of substrate numbers this package's
design is budgeted against, and fails when one goes over. The benchmarks are
in `ci/perf.el`; the numbers are in the `:perf` table of `ci/config.el`, where
every other policy number lives. `make perf` prints the same table and never
fails, which is the form it takes in a pull request: numbers to look at, not a
red mark on a shared runner. The strict check is left to the nightly run,
where a stray red mark costs nobody a merge.

| benchmark | budget | why it is guarded |
|---|---|---|
| `insert-per-chunk` | max 0.10 ms | an absolute sanity floor for a 50-byte insert |
| `insert-size-ratio` | max 3.0 | insert in a 20 000-line buffer over an empty one; an accidental walk shows up here first |
| `redisplay-per-chunk` | max 4.00 ms | the only expensive thing a stream does |
| `batch-ratio` | min 4.0 | how much cheaper a redisplay every 20 chunks is; a ratio survives a slow machine |
| `filter-events-per-call` | max 2.0 | above one means the process layer coalesces deliveries |
| `filter-gap-spread` | max 25.0 ms | widest minus narrowest delivery gap; a stall shows up here |
| `json-per-event` | max 0.10 ms | parsing one streamed event |

Two of them need a terminal, because `redisplay` paints nothing in batch mode.
`ci/run-perf.sh` hands Emacs a terminal through `script` when it can, spelling
out the BSD and GNU argument orders; without it those two report `skip` rather
than fail. That is deliberate: a budget that cannot be measured is not a
failure, and pretending otherwise teaches people to ignore the output.

A run that dies is not a skip. The error goes to stderr, the table is never
written and the script exits non-zero saying no measurements were produced --
the distinction the CI step already draws, now with the reason next to it. The
tty run has to be told to exit on an error: a batch Emacs does that by itself,
but an interactive one prints the error and returns to its command loop, which
`script' keeps alive until the timeout five minutes later. That is how a typo
in a benchmark turned into an empty job log.

A package's own hot path is measured in `config/perf.el`, which `ci/perf.el`
loads when it exists: register one there with `p/defperf` and add its budget to
the `:perf` table in `config/ci.el`. A benchmark without a budget is reported as
`no budget` rather than silently passing. Nothing is written for you, because
an empty file is a worse reminder than the sentence in `config/ci.el`.

The numbers are guarded while there is no code to guard, on purpose. They are
the constants the design rests on, so an Emacs upgrade or a hostile
configuration that changes them is worth learning about before the first
benchmark of our own exists.

## Size

`make size` prints two things: what each module costs, and where the same run
of lines sits twice. The measuring is in `ci/size.el`; where it looks is the
`:size` table of `ci/config.el`, next to every other policy number. The
default is `lisp/` plus the repository root, which counts a package's entry
point as the module it is; a second table in `config/ci.el` is only needed
when the layout or the run length differs.

```
size: 4210 lines in 14 modules, 163 definitions
size: largest console.el, 812 lines and 41 definitions
size: 2 over 300 lines: console 812, session 331
size: 1 run of 4 lines or more, 5 lines in them, longest 5
size:  5  console.el:120 and console.el:133  (with-current-buffer buffer
```

The last line is the first line of the repeated run, which is what makes a
report actionable: the run is named by `module:line`, and the reader opens
two places rather than searching for a paragraph.

There is no budget and no stricter variant, because a number that fails a
build is a number somebody pads around. A console is the largest module
because presentation is the widest thing in it, not because it is wrong. What
the table answers is the question a candidate list asks before a refactor --
is this duplication, and can it be named? -- and the proof of that unit is the
call sites it collapses, N to one, not the lines it deletes.

A package that can count something else sets `p/size-definitions` in
`config/size.el`, which `ci/size.el` loads when it exists, to a function that
returns how many definitions belong to one file; the report then grows a
column, and without the file it prints lines and runs alone. A `:window` of
four is the default because three matched lines is a shape two modules share
by accident.

The match is on text, which the report says by being quiet: a run that is one
idea with different names is invisible, so an empty table means nobody
copy-pasted, not that nothing is duplicated.

## Coverage

`make coverage` instruments the source, runs the ERT suite in a throwaway
Emacs, and prints what the tests reached.  The measuring is testcover-audit;
where it looks is the `:coverage` table of `ci/config.el`, whose default is
the same source set as `:size` -- the modules under the submodule directory
plus the entry point at the root.  Test and vendored files are never
instrumented.

```
coverage: ERT ran 394 tests, 2 unexpected
coverage: 93% (covered 6410, 1value 1775, uncovered 612, total 8797)
```

The table above the totals line names each module, so a low number has an
address.  The same data is written to `build/coverage.json`; CI uploads both
the log and the JSON as the `coverage` artifact.

The percentage is testcover-audit's: a form that always took the same value
counts as covered, because the test did run it.  The totals line prints that
count separately as `1value`, so a number that looks healthy while most forms
never varied is visible in the same place as the number itself.  A report is
not the place to hide that distinction behind one percentage.

There is no budget and no stricter variant, and the pipeline treats it like
`make perf` and `make size`: a report that is uploaded, never a check that
fails.  The reason is stronger here than for timing.  Instrumentation changes
what the code does -- every form gains a wrapper that records a value -- so a
suite with timing assertions can be red under coverage and green in
`make test`.  In the pilot run, two assertions in one package's console
tests failed only when instrumented; both were timing budgets, not
behaviour.  Correctness is the test job's verdict.  This job's
verdict is that a report exists.

That also means ERT failures are printed and counted but do not decide the
exit status.  Each test runs on its own, so an assertion that escapes ERT --
one placed in a timer or a process sentinel, which instrumentation can turn
from a race won into a race lost -- costs that test's result and not the rest
of the report; the reason is printed above the table.  Three things do fail
the run, because each means there is no report rather than a bad one: a file
that cannot be instrumented, a test file that cannot be loaded, and a scan
that collects no coverage data at all.  A package with no test modules prints a
skip line and exits zero, the same way `make test` does.

Coverage needs interpreted code: `testcover` instruments the `.el` it reads,
and a test that loads the `.elc` instead reaches the compiled definition and
records nothing.  The suite's byte-compile check compiles to a temporary
destination, so the source tree stays interpreted, but a package with its own
build step has to keep that step out of the coverage run.  Top-level forms
also run twice, once at instrumentation and once when a test requires the
file; that is harmless for definitions and worth knowing for anything with a
side effect.  Both are reasons the run happens in its own Emacs and its own
job, not as a wrapper around `make test`.

The report is deliberately broader than the gate would be: `make coverage`
succeeds and prints, and a reader decides what the number means.  A floor
would turn a measurement into a target, and a target into a number that gets
padded around.

## Requirements

- `emacs` on `PATH`, or `EMACS=/path/to/emacs`.
- Network on first run only: `ci/deps.el` installs `package-lint` for the
  checks and `testcover-audit` for `make coverage` into `.cache/elpa` unless
  they are already available in `~/.emacs.d/elpa`.

## Secrets (notifications)

| secret | meaning |
|---|---|
| `SMTP_HOST`, `SMTP_PORT` | SMTP server (port 465, implicit TLS) |
| `SMTP_USER`, `SMTP_PASS` | SMTP credentials; `SMTP_USER` is also the sender |
| `NOTIFY_EMAIL` | recipient |

When `SMTP_HOST` is unset (for example on a fork pull request) the mail is
skipped silently.  That gate lives in `.github/actions/send-mail`, which every
report goes through, because a step's `if:` cannot read `secrets`: putting the
check in one action beats turning an empty secret into an output at every call
site.  The MELPA announcement checks the same input for a second reason -- it
writes no `melpa-published` tag without a host, so an unconfigured repository
cannot record an announcement it never made.

## Shared actions

Seven things are used more than once and are defined once:

| action | why it exists |
|---|---|
| `setup-emacs` | the guarded apt install and the version line were copied into several actions and drifting |
| `send-mail` | the only place that knows an empty `SMTP_HOST` means silence |
| `melpa-status` | the only place that knows what "published" means: melpazoid asks it whether the recipe exists, and the announcement asks it for the page, the recipe URL and the count |
| `mail-card` | the frame both cards are built in: header colour, title, footer, and nothing about the message |
| `notify-melpa` | the once-only announcement: checks the `melpa-published` tag, mails, writes the tag |
| `notify-failure` | builds the report, reads the run's identity from the `github` context, hands it to `send-mail` |
| `perf` | the pull request run and the nightly run execute the same thing, differing only in whether a budget that is over fails |

`notify-failure` takes `stage` and the SMTP inputs and nothing else.  The
repository, ref, commit and run URL come from `github`, which a composite
action can read — passing them in only gave six call sites a chance to
disagree with the run they were reporting on.

What is deliberately not shared: the six `if: failure()` blocks stay at each
job, because the report attaches the `build/*.log` files of *that* runner.  A
single `needs:`-based notify job cannot see another job's filesystem, so
merging them would cost the logs, which are the useful part.
