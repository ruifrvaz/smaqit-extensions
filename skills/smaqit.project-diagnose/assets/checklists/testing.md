# Testing Checklist

12 checks for test infrastructure completeness.

| Check | Pass Condition |
|-------|----------------|
| Backend test files exist | Count > 0 |
| Frontend test files exist | Count > 0 |
| Backend test runner configured | Language-specific runner config present (e.g. `[tool.pytest]`, `jest.config.*`, Maven Surefire, `go test`) |
| Backend test fixtures / setup file present | Fixture or setup file present for the detected language (e.g. `conftest.py`, `testify`, `spec_helper.rb`) |
| Frontend test runner configured | Test runner config present (e.g. `vitest.config.*`, `jest.config.*`) |
| Backend test coverage configured | Coverage reporting configured in package manifest or dedicated coverage config |
| Backend coverage threshold set | Coverage threshold configured and non-zero |
| Frontend test coverage configured | Coverage reporter configured in frontend package manifest or test runner config |
| CI workflow runs backend tests | Backend test runner invoked in at least one non-smaqit workflow |
| CI workflow runs frontend tests | Frontend test runner invoked in at least one non-smaqit workflow |
| Tests do not import production `.env` | No direct `.env` file read in test files (e.g. `load_dotenv`, `open(".env")`, `dotenv.config()`) |
| Test isolation: no shared mutable state across modules | No session-scoped fixtures that mutate global state without explicit teardown |
