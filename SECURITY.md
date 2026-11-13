# Security policy

This policy applies to every repository of the IT-Titans organization that
does not carry a `SECURITY.md` of its own.

## Reporting a vulnerability

Do not open a public issue, pull request or discussion for a security problem.

Report it through GitHub private vulnerability reporting:

1. Open the affected repository on GitHub.
2. Select the **Security** tab.
3. Select **Report a vulnerability** and fill in the form.

The report is visible only to you and to the maintainers of that repository.

If the repository does not offer **Report a vulnerability**, use the contact
form at https://it-titans-gmbh.com/en/contact-us/. Start the message with the
word "Security" and the name of the repository, and leave the technical details
out. We then open a private channel with you.

A useful report says what the problem is, how to reproduce it, which commit or
release you looked at and what an attacker could achieve. A proof of concept
helps, but a clear description is enough to start.

## What happens next

| Step | Our commitment |
|---|---|
| Acknowledgement | within 3 working days |
| Initial assessment | within 10 working days |
| Progress updates | at least every 14 days while we work on the report |

We tell you how we assess the report and what we intend to do. If we do not
consider something a vulnerability, we say so and explain why.

## What to expect per repository

The **Status** line near the top of each README names the class of the
repository. The class decides what follows a confirmed report.

| Class | What we do |
|---|---|
| product, maintained | We fix the problem on the default branch and publish a GitHub security advisory. |
| frozen | The repository is an archived example or proof of concept and receives no fixes. We still read the report. A confirmed problem leads to a warning in the README. |
| fork | Report the problem to the upstream project. Tell us as well if the problem exists only in our fork. |

## Scope

In scope is the code in the repositories of this organization.

This policy does not permit testing against systems operated by IT Titans GmbH
or by its customers. Ask first and describe what you intend to do; without our
written agreement, confine your tests to an instance you run yourself.

Out of scope are reports produced solely by an automated scanner without a
demonstrated impact, missing hardening headers with no exploitable consequence,
denial of service through volume alone, and social engineering against our
staff.

## Credit

Tell us how you would like to be credited. We name you in the advisory or the
release notes of the fix, or leave your name out if you prefer.
