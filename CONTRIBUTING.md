# Contributing to Aether OnRamp

Thank you for your interest in contributing to Aether OnRamp! This document provides guidelines for contributing to the project.

## Code of Conduct

Please be respectful and constructive in all interactions. We are committed to providing a welcoming and inclusive environment for everyone.

## How to Contribute

### Reporting Issues

If you encounter a bug or have a feature request:

1. Check existing issues to avoid duplicates
2. Create a new issue with a clear title and description
3. Include:
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (OS, Kubernetes version, etc.)
   - Logs or screenshots if applicable

### Submitting Changes

1. **Fork the Repository**
   ```bash
   git clone https://github.com/cput-it-advdip/aether-open5g.git
   cd aether-open5g
   ```

2. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Write clear, concise commit messages
   - Follow existing code style and conventions
   - Update documentation as needed
   - Add tests if applicable

4. **Test Your Changes**
   - Test on AWS EC2 t3.large if possible
   - Verify all documentation links work
   - Run any existing tests

5. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "Add feature: description of changes"
   ```

6. **Push to Your Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Provide a clear description of changes
   - Reference any related issues
   - Wait for review and address feedback

## Development Guidelines

### Documentation

- Use clear, concise language
- Include code examples where appropriate
- Test all commands and configurations
- Keep documentation up to date with code changes

### Configuration Files

- Use YAML for configuration
- Include comments explaining options
- Validate YAML syntax before committing
- Follow existing formatting conventions

### Scripts

- Use bash for shell scripts
- Include error handling
- Add usage instructions
- Make scripts idempotent where possible

### Commit Messages

Follow this format:
```
<type>: <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

Example:
```
feat: Add support for multi-node Kubernetes clusters

- Implement kind configuration for multi-node setup
- Update documentation with multi-node examples
- Add validation for node resources

Fixes #123
```

## Testing

### Manual Testing

Before submitting a pull request:

1. Test installation on clean AWS EC2 t3.large instance
2. Verify Kubernetes cluster setup
3. Test SD-Core deployment
4. Verify RAN connectivity (if applicable)
5. Check all documentation links

### Documentation Testing

- Verify all commands work as documented
- Test configuration examples
- Ensure screenshots are current
- Check for broken links

## Areas for Contribution

We welcome contributions in these areas:

### Documentation
- Improving existing documentation
- Adding tutorials and guides
- Creating video walkthroughs
- Translating documentation

### Configuration
- Additional deployment scenarios
- Performance optimization examples
- Alternative configurations
- Cloud provider variations

### Automation
- CI/CD pipelines
- Testing automation
- Deployment scripts
- Monitoring tools

### Features
- Additional RAN support
- Enhanced monitoring
- Performance improvements
- Security enhancements

## Questions?

If you have questions about contributing:
- Open an issue with the `question` label
- Review existing documentation in `docs/`
- Check closed issues for similar questions

## Recognition

Contributors will be recognized in:
- Project README
- Release notes
- Documentation credits

Thank you for contributing to Aether OnRamp!
