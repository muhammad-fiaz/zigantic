# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.0.2   | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability within zigantic, please follow these steps:

### 1. Do NOT Create a Public Issue

Please **do not** open a public GitHub issue for security vulnerabilities. This helps protect users while we work on a fix.

### 2. Report Privately

Send a detailed report to:

- **Email**: [Create a private security advisory](https://github.com/muhammad-fiaz/zigantic/security/advisories/new)
- **GitHub Security Advisories**: Use the "Report a vulnerability" button on the Security tab

### 3. Include Details

Please include the following information in your report:

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact
- Suggested fix (if any)
- Your name/handle for credit (optional)

### 4. What to Expect

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Assessment**: We will assess the vulnerability and determine its severity
- **Updates**: We will keep you informed of our progress
- **Fix**: We will work on a fix and coordinate a release
- **Credit**: With your permission, we will credit you in the release notes

## Scope

This security policy applies to:

- The zigantic library (`src/` directory)
- Official examples (`examples/` directory)
- Build scripts (`build.zig`, `build.zig.zon`)

## Out of Scope

- Third-party dependencies
- User applications built with zigantic
- Documentation website infrastructure

## Security Best Practices

When using zigantic, we recommend:

1. **Keep Updated**: Use the latest version of zigantic
2. **Validate All Input**: Never trust user input
3. **Handle Errors**: Always handle validation errors appropriately
4. **Use Secret Types**: Use `z.Secret` for sensitive data like passwords

## Automatic Update Checking

zigantic includes automatic update checking to help you stay current with security patches. This feature:

- Runs in the background on first JSON function use
- Notifies you of available updates
- Can be disabled with `z.disableUpdateCheck()` if needed

Thank you for helping keep zigantic and its users safe!
