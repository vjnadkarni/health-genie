# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: health-genie

This is a Python 3.13 project. The project uses a virtual environment located in the `venv/` directory.

## Development Setup

### Virtual Environment
The project uses a Python virtual environment. Always ensure you're working within the activated environment:
```bash
source venv/bin/activate  # On macOS/Linux
```

### Installing Dependencies
When a requirements.txt file exists:
```bash
pip install -r requirements.txt
```

For development dependencies (when requirements-dev.txt exists):
```bash
pip install -r requirements-dev.txt
```

## Project Structure Guidelines

Since this is a new project, follow these conventions when creating the structure:

- Place main application code in a `health_genie/` or `src/` directory
- Use snake_case for Python files and directories
- Create a `tests/` directory for test files
- Add configuration files (requirements.txt, setup.py, pyproject.toml) at the root level

## Code Standards

- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Create docstrings for modules, classes, and functions
- Prefer pathlib.Path over os.path for file operations

## Important Reminders

- Do what has been asked; nothing more, nothing less
- NEVER create files unless they're absolutely necessary for achieving the goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested