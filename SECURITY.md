# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.4.x   | :white_check_mark: |
| 1.3.x   | :white_check_mark: |
| < 1.3   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it
responsibly:

1. **Do NOT open a public issue** for security vulnerabilities
2. Email the maintainer directly at: zac@zacbowling.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes

## Response Timeline

- **Initial response**: Within 48 hours
- **Status update**: Within 7 days
- **Fix timeline**: Depends on severity, typically within 30 days

## Scope

This security policy covers:

- The patch files in `kernels/`
- The DKMS package in `dkms/`
- Build and installation scripts

Note that the underlying mt76 driver code originates from the Linux kernel.
Vulnerabilities in the upstream driver should be reported to the Linux kernel
security team: security@kernel.org

## Recognition

Contributors who report valid security issues will be acknowledged in the
release notes (unless they prefer to remain anonymous).
