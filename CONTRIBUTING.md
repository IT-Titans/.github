# Contributing

These guidelines apply to every repository of the IT-Titans organization that
does not carry a `CONTRIBUTING.md` of its own. Where a repository has its own
file, that file wins.

## Check the status of the repository first

The **Status** line near the top of each README names the class of the
repository. The classes are defined in the
[repository standard](https://github.com/IT-Titans/.github/blob/main/docs/repository-standard.md).

| Class | Contributions |
|---|---|
| product, maintained | Welcome. Read the rest of this page. |
| frozen | Not accepted. The repository is an example or proof of concept in its final state and is archived, so issues and pull requests cannot be opened. Fork it if you want to build on it. |
| fork | Send changes to the upstream project. |

## Before you start

Open an issue before you work on anything larger than an obvious fix. A short
discussion shows whether the change fits and whether someone is already working
on it.

Security problems are the exception. Do not open a public issue for them; follow
the security policy of the repository, which you find under its **Security**
tab.

## Making a change

1. Fork the repository and create a branch from the default branch.
2. Make the change and add tests for it. A bug fix needs a test that fails
   without the fix.
3. Run the tests and the format check the way the README of the repository
   describes.
4. Open a pull request against the default branch. Say what changes and why,
   and how you verified it.

Keep a pull request to one purpose. Reformatting unrelated files hides the
actual change from the reviewer.

## Pull request titles

Pull requests are merged by squash, and the title of the pull request becomes
the commit message on the default branch. The title must therefore be a
[Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/):

```
feat: add a rule for stale service connections
fix(parser): handle an empty organization name
docs: explain the token scopes a full audit needs
```

The allowed types are `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`,
`refactor`, `revert`, `style` and `test`. A `!` after the type marks a breaking
change. Repositories that use the shared workflow check the title
automatically.

## Tests and coverage

New behaviour needs tests. Repositories of the classes product and maintained
enforce a minimum line coverage in CI, for the whole solution and for each
assembly or package. A change that lowers either below the minimum does not
pass.

Run the whole suite, not only the project you touched. A run that reports "No
test is available" for a project has skipped that project, even when the exit
code is zero.

## Language

Source code, comments, commit messages, issues, pull requests and documentation
are written in English.

## Licence of your contribution

Unless the repository says otherwise, you contribute under the licence of that
repository. This is the rule of the
[GitHub Terms of Service, section D.6](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#6-contributions-under-repository-license).
A repository that needs more than that, for example a contributor licence
agreement, says so in its own `CONTRIBUTING.md`.

Do not add a dependency whose licence is incompatible with the licence of the
repository.

## Conduct

Everyone who takes part is expected to follow the
[code of conduct](https://github.com/IT-Titans/.github/blob/main/CODE_OF_CONDUCT.md).
