# .github

The organization-wide defaults of [IT-Titans](https://github.com/IT-Titans):
the organization profile, the community health files every repository inherits,
two reusable workflows with their starters, and the repository standard those
pieces implement.

## Status

Class: maintained. Changes to this repository take effect in every repository
of the organization, so they go through a pull request.

## What is in here

| Path | Effect |
|---|---|
| `profile/README.md` | Shown on the organization page. |
| `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md` | Default for every repository that has no file of the same name in its root, its `.github` folder or its `docs` folder. |
| `.github/ISSUE_TEMPLATE/` | Default issue forms and template chooser for every repository that has no `.github/ISSUE_TEMPLATE` folder of its own. |
| `.github/pull_request_template.md` | Default pull request template. |
| `.github/workflows/conventional-pr-title.yml` | Reusable workflow: the title of a pull request must be a Conventional Commit. |
| `.github/workflows/dotnet-ci.yml` | Reusable workflow: build and test a .NET solution and enforce a minimum line coverage for the total and for every assembly. |
| `.github/workflows/ci.yml` | CI of this repository. |
| `.github/dependabot.yml` | Keeps the pinned actions of this repository current. Not inherited by other repositories. |
| `workflow-templates/` | Starters that call the two reusable workflows. They appear under **Actions > New workflow** in every repository of the organization. |
| `docs/repository-standard.md` | The rules every public repository follows, with the reason for each. |
| `tests/` | Tests for the scripts inside the reusable workflows. |

### What a repository does not inherit

GitHub applies the defaults only for the file types listed above. Each
repository still needs its own:

- `LICENSE`. GitHub does not support a default licence.
- `README.md`.
- Workflows. A workflow in this repository runs only here; other repositories
  call the reusable workflows from a workflow file of their own.
- `CODEOWNERS`, `dependabot.yml`, `.gitignore`, `.gitattributes` and
  `.editorconfig`.
- Settings such as rulesets, merge options and security features.

A repository that carries any file in its own `.github/ISSUE_TEMPLATE` folder
gets none of the default issue forms and not the default template chooser.

The defaults are displayed on GitHub. They are not part of a clone or a
download of the inheriting repository.

## Prerequisites

PowerShell 7.4 or later, to run the tests. Nothing else.

## Quick start

Run the tests from the root of the repository:

```sh
pwsh ./tests/Test-WorkflowScripts.ps1
```

The last line reports the number of checks and deviations. The exit code is 0
when there are no deviations.

## Configuration

### Using the reusable workflows

In the repository that needs the workflow, open **Actions > New workflow** and
choose the starter from the section of the organization. The starter pins the
reusable workflow to a full commit SHA with the release tag as a comment. The
same files are in [`workflow-templates/`](workflow-templates) if you prefer to
copy them.

`conventional-pr-title.yml` takes one input:

| Input | Default | Meaning |
|---|---|---|
| `types` | `build chore ci docs feat fix perf refactor revert style test` | Allowed types, separated by spaces. |

The calling workflow must run on `pull_request` with the activity types
`opened`, `edited`, `reopened` and `synchronize`. Without `edited`, correcting
the title does not run the check again.

`dotnet-ci.yml` takes these inputs:

| Input | Default | Meaning |
|---|---|---|
| `solution` | empty | Path to the solution. Empty means the single solution in the repository root. |
| `runsettings` | empty | Path to the runsettings file of the coverage collector. Empty means the defaults of the collector. |
| `minimum-line-coverage` | `90` | Required line rate in percent, for the total and for every assembly. |
| `required-assemblies` | empty | Assemblies that must appear in the merged report. An assembly no test loads is otherwise missing without notice. |
| `runs-on` | `ubuntu-latest` | Runner label. WPF and Windows Forms need `windows-latest`. |
| `dotnet-version` | empty | SDK version. Empty means `global.json` in the repository root, and the run fails when that file is missing. |
| `fetch-depth` | `1` | Commits to fetch. Version tools such as Nerdbank.GitVersioning need `0`. |
| `verify-format` | `true` | Run `dotnet format --verify-no-changes` before the build. |

The test projects must reference `coverlet.collector`. The job uploads two
artifacts, `test-results` and `coverage-report`; call the workflow once per
workflow run, because a second call would collide on those names.

The check that a ruleset can require is named after both jobs, the calling one
and the called one, for example `dotnet / Build, test and coverage`. Read the
exact name off the first run before adding it to a ruleset.

### Releasing a change to a reusable workflow

Pull requests are merged by squash, so the commit of a pull request does not
survive the merge. A change therefore reaches the starters in three steps:

1. Merge the pull request that changes the workflow.
2. Tag the resulting commit on `main` with the next version, `vX.Y.Z`, and push
   the tag.
3. Open a second pull request that sets the commit SHA and the version comment
   in `workflow-templates/` to that tag.

Repositories that already call the workflow keep their pinned commit until
they update the reference, by hand or through Dependabot version updates for
the `github-actions` ecosystem.

## Tests

`tests/Test-WorkflowScripts.ps1` reads the inline scripts out of the workflow
files and runs each against known inputs, the way the runner does. Every check
has inputs that must fail: titles that are not Conventional Commits, a report
with one assembly below the minimum, a runsettings file that excludes
compiler-generated code, a repository without `global.json`.

It also checks rules on the files themselves: every action is pinned to a
commit SHA, every workflow starts with read-only permissions, no script
contains a workflow expression, every starter has metadata that parses, and the
pull request template contains no text that a check could mistake for an issue
reference.

What the tests cannot cover is the behaviour of GitHub itself: triggers,
`if:` conditions, the actions and the runner images. That part is verified by a
run on GitHub.

## Security

Report vulnerabilities as described in [SECURITY.md](SECURITY.md), never in a
public issue.

## License

[Apache-2.0](LICENSE). Copyright 2026 IT Titans GmbH.
