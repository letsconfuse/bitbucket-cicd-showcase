# Contributing Guidelines

Thank you for your interest in contributing to our project!

## Branching Strategy
- **`main`**: Represents the stable, production-ready state of the code. Deployments to production happen from here.
- **`develop`**: The integration branch for new features. Staging deployments happen from here.
- **Feature Branches**: Should be branched off `develop`. Name them clearly based on the work being done (e.g., `feature/login-system`, `bugfix/auth-issue`).

Workflow: `feature-branch` → `develop` → `main`

## Commit Conventions
We use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
Format: `<type>(<scope>): <description>`
Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

## Pull Request Process
1. Ensure your code follows the established style guidelines.
2. Ensure tests pass and the pipeline is green.
3. Open a PR against `develop` (for features) or `main` (for hotfixes).
4. Request reviews from the appropriate team members.
5. Address any feedback and merge only when approved.

## Adding New Deployment Targets
To add a new target environment (e.g., UAT):
1. Duplicate the relevant staging or production steps in the `bitbucket-pipelines.yml` files.
2. Configure the new target environment in Bitbucket Deployments.
3. Add the necessary target environment variables in the Bitbucket repository settings.
4. Document the new environment in `docs/runbook.md`.

## Testing Pipeline Changes
1. Since pipeline changes can be disruptive, test them thoroughly in a separate branch.
2. You can use the "Run pipeline" feature in Bitbucket to manually trigger custom pipelines for testing scripts and commands.
3. Verify that changes to one OS pipeline (e.g., Windows) do not break the counterpart (Linux) if both are active.
