# Repository standard

Version of 2026-11-13. This document is normative for every public repository
of the IT-Titans organization. "Must" marks a requirement. Each rule is followed
by the reason for it, because a rule without a reason gets dropped the first
time it is inconvenient.

## Principle

A public repository that is not archived is a maintenance promise made under
the name of the company. A visitor cannot tell an abandoned repository from a
maintained one unless the repository says so.

Each repository is therefore in one of two states. It is maintained to the
standard of its class, or it has been brought to a clean final state once and
archived. Archiving is reversible and deletes nothing. A third state, public
and unattended, does not exist.

## Classes

Every repository belongs to exactly one class. The class is stated in the
**Status** line of the README.

| Class | Meaning | Target state |
|---|---|---|
| product | Software that IT Titans operates or offers to third parties. | Maintained to the baseline and the additional rules. |
| maintained | A tool or reference project under active development whose build output people use. | Maintained to the baseline and the additional rules. |
| frozen | An example, comparison or proof of concept with no further development. | Brought to the baseline once, then archived. |
| fork | A fork of a project owned by someone else. | Kept only with a stated purpose; otherwise archived. |

A new repository gets its class when it is created.

## Baseline for every public repository

### B1 Identity

The repository must have an accurate description of one English sentence, three
to eight topics, a homepage URL where one exists, and a custom social preview
image made with the shared banner generator.

Why: the repository list is what a visitor sees first. Description and topics
decide whether the repository is found and understood without opening it. The
social preview is the image shown wherever a link to the repository is posted.

### B2 README

The README must be written in English and contain these sections in this order:

1. Title and one paragraph that states the purpose.
2. Status: the class, and for a frozen repository the line
   "Last verified: <date> with <toolchain versions>".
3. Prerequisites.
4. Quick start that works when copied verbatim.
5. Configuration.
6. Tests, where the repository has any.
7. Security, pointing to the security policy.
8. License.

The README must not contain internal identifiers: no tenant, subscription,
application or object IDs and no internal host names.

Why: the Status line tells the reader what to expect before they invest time.
A quick start that fails when copied is worse than none, because it costs the
reader an hour before they find out. Internal identifiers help an attacker map
our infrastructure and help no reader.

### B3 Licence

The repository must contain a `LICENSE` file that GitHub detects, which means
the licence shown for the repository has an SPDX identifier other than
`NOASSERTION`.

- product: AGPL-3.0-or-later, with a commercial licence offered alongside.
- every other class: Apache-2.0.

The copyright holder is IT Titans GmbH.

Why: without a licence nobody may use the code, even though everybody can read
it. A licence file GitHub cannot classify is treated by tools and by cautious
users the same way as no licence. A default licence cannot be inherited from
the organization; each repository must carry its own file so that the licence
travels with every clone and download.

### B4 Community health

`SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, the issue
forms and the pull request template come from the organization-wide
[`.github`](https://github.com/IT-Titans/.github) repository. A repository
carries its own copy of one of these files only where its content must differ.

Why: one place to maintain instead of one per repository, and no repository
without a security policy because someone forgot to add one. A copy that says
the same as the default only creates a second text that goes stale.

### B5 Security settings

These settings must be on: secret scanning, push protection, the dependency
graph, Dependabot alerts and private vulnerability reporting. The dependency
graph must also be non-empty, which means GitHub has recognised the manifest
and lock files.

Tracked files must not contain credentials. The only exception is a demo
default in `.env.example` that is labelled as such.

Why: a reporter needs a confidential way to reach us, and an alert can only
fire for a dependency GitHub knows about. A switch that is on proves little;
the evidence is a populated dependency graph. Secret scanning recognises the
formats of known providers and does not notice a hand-written password, so the
rule on tracked files does not depend on it.

### B6 Hygiene

The repository must contain `.gitignore`, `.gitattributes` and `.editorconfig`.
Lock files must be tracked. Build output and dependencies must not be tracked.

Why: these three files decide whether a clone on another machine and another
operating system builds the same way. A tracked lock file is what makes a build
reproducible; tracked build output makes every diff unreadable.

### B7 Merge settings

Squash merge must be the only allowed merge method. The title of the pull
request becomes the title of the commit. Branches are deleted when their pull
request is merged. Commit titles on the default branch follow
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Why: one commit per change gives a history that can be read and from which
release notes can be generated. Since the squash commit takes the title of the
pull request, the title is what has to follow the convention. The reusable
workflow `conventional-pr-title.yml` checks it.

### B8 Protected default branch

A repository ruleset must protect the default branch against force pushes and
against deletion. The ruleset must be active, not in evaluation mode.

Why: the history of a public repository must not change silently. Other people
have cloned it and refer to its commits.

## Additional rules for the classes maintained and product

### M1 Continuous integration

CI must run on every pull request and on the default branch. It must restore,
build, test and check formatting or lint.

Every action and every reusable workflow from another repository must be pinned
to a full commit SHA, with the version as a trailing comment. Every workflow
must set `permissions: contents: read` at the top level and grant a job more
only where the job needs it.

Why: a tag can be moved to different code by whoever controls the repository of
the action; a commit SHA cannot. A token that starts read-only limits what a
compromised step can do.

### M2 Coverage

CI must enforce 90 % line coverage for the total and for every assembly or
package. The measurement must meet these conditions:

- It is taken in the Release configuration.
- It is taken on the merged report of all test projects.
- Every production project is part of it, UI projects included.
- Compiler-generated code is not excluded.
- Exclusions are explicit, minimal and justified in the configuration file.

A gate counts as working only after it has been seen failing once.

Why, condition by condition:

- A total alone hides the weak spot. In one of our projects the total stood at
  93.9 % while the assembly that decides what counts as a finding stood at
  68.5 %.
- Each test project writes its own report, and the reports overlap. A line is
  covered when any test project reaches it. ReportGenerator unions the hits;
  reading one report per assembly undercounts, in the same project by 14
  points for one assembly.
- A project that no test loads does not appear in any report. If it is left
  out, the figure describes less code than the repository contains.
- Excluding `CompilerGeneratedAttribute` also drops every async state machine.
  In the same project that took one assembly from 7480 countable lines to 4014
  and raised its figure from 23.6 % to 36.0 % without a single new test.
- A check that has never failed may be unable to fail. We have had a required
  check that passed because the pull request template contained an example
  that satisfied it.

The reusable workflow `dotnet-ci.yml` implements this rule for .NET.

### M3 Pinned toolchain

The versions of the toolchain must be pinned in the repository: `global.json`
with `rollForward: latestFeature` for .NET, and `packageManager` or `.nvmrc`
for Node.js.

Why: when only a Dockerfile or the CI configuration names the version, the
developer machine and the pipeline build with different compilers, and a
problem shows up in one place and not in the other.

### M4 Ruleset

The ruleset of the default branch must additionally require a pull request and
the CI checks. An approving review is not required while the repository has a
single active maintainer.

Why: a change that reaches the default branch without CI has not been tested.
A required approval without a second person is either bypassed or blocks all
work, and a rule that is bypassed routinely teaches people to bypass rules.

### M5 Dependency updates

Dependency updates must be automated: Dependabot version updates where GitHub
hosts the source of truth, Renovate where Azure DevOps does. Dependabot
security updates and the CodeQL default setup must be on.

Why: a framework reaching its end of support should be reported by a tool on
the day it happens, not found by a review months later.

### M6 Releases

Releases must be tagged `vX.Y.Z` following Semantic Versioning. Each tag has a
GitHub Release with the binaries attached. Release notes are generated from the
Conventional Commits since the previous tag.

Why: artifacts of GitHub Actions expire after 90 days and are not a
distribution channel. A download link in a README must point to something that
still exists next year.

### M7 Documentation

The repository must contain an overview of its architecture, architecture
decision records for decisions that constrain future work, and a changelog or a
`docs/releases` folder.

Why: knowledge that exists only in the heads of the people who built something
leaves with them.

## Final-state procedure for the class frozen

The coverage rule M2 does not apply to frozen repositories. The verification
stamp of step F2 takes its place.

### F1 Bring the repository to the baseline

One pull request, titled as the final state, brings the repository to B1 to B8.

Why: one reviewable change with one purpose, after which nothing further is
planned.

### F2 Verify the quick start and stamp the README

The documented quick start must be run once. The README then states
"Last verified: <date> with <toolchain versions>", naming the versions of the
tools used.
What could not be verified must be stated next to it.

Why: an example is only worth keeping if it worked at a known point in time.
The stamp tells a later reader how old that knowledge is, and an honest gap is
more useful than a silent one.

### F3 Apply the settings before archiving

Settings, topics, description and social preview must be applied before the
repository is archived.

Why: an archived repository is read-only, including most of its settings. What
is not set before archiving requires unarchiving first.

### F4 Archive

The repository is archived. Unarchiving reverses the step.

Why: the archive banner is the clearest signal GitHub offers that nobody will
answer an issue here, and it keeps the content available.

## Where the rules are implemented

| Rule | Implementation in the `.github` repository |
|---|---|
| B4 | `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md` |
| B7 | `.github/workflows/conventional-pr-title.yml` |
| M1, M2 | `.github/workflows/dotnet-ci.yml` |
| Starters for both workflows | `workflow-templates/` |
