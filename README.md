# Flutter extension for Gemini CLI

Help Gemini CLI create, build, test, and run Flutter apps.

*   **Status: Experimental** - This is an experimental repository. Features and commands may change drastically. We welcome your feedback!

## ✨ Features

-   **🚀 Project Bootstrapping**: Create new Flutter projects from scratch with built-in best practices, including linters, documentation, and design planning.
-   **🔧 Guided Refactoring**: Execute complex refactoring tasks with automated planning, git branch management, and step-by-step implementation guides for your approval.
-   **✅ Automated Pre-Commit Checks**: Automatically format, analyze, and test your code before committing to maintain codebase quality.
-   **✍️ Smart Commit Messaging**: Generate descriptive, conventional commit messages based on your staged changes.
-   **🧠 Context Priming**: Initializes Gemini with specific rules and context for Dart and Flutter, ensuring high-quality, idiomatic code generation.

## 📋 Prerequisites

1.  **Gemini CLI 0.4.0+** installed and configured.
2.  **Flutter & Dart SDK** installed on your system.
3.  **Git** installed and available in your PATH.

## 🚀 Installation

### 1. Install from GitHub

Use the `gemini extensions install` command to install directly from the source repository:

```bash
gemini extensions install --source https://github.com/gemini-cli-extensions/flutter.git
```

You can manage the extension with the following commands:

```bash
# Update to the latest version
gemini extensions update flutter

# Uninstall the extension
gemini extensions uninstall flutter
```

### 2. Available Commands

The new commands will be available in new terminal sessions. The following commands will be available (with or without the `flutter:` prefix):

-   `/start` - Primes Gemini with the rules and context for Flutter development.
-   `/create-app` - Guides you through bootstrapping a new Flutter project with best practices.
-   `/refactor` - Manages a structured refactoring session with automated planning.
-   `/commit` - Automates pre-commit checks and generates a descriptive commit message.

## 💡 Usage

This extension provides powerful commands to automate key phases of the development lifecycle.

### `/start`

Initializes Gemini with the proper context for Flutter development. It summarizes the coding guidelines, documentation rules, and available tools. **Use this command at the beginning of a session.**

```bash
/start # Initialize context to start a session
/start What were we last doing in this app? # Start a session and pick up where you left off
```

### `/create-app`

Initiates a guided process to bootstrap a new Flutter application, ensuring your project starts with a solid foundation.

**Process:**
1.  Asks for the package's purpose, details, and desired location on your filesystem.
2.  Creates a new Flutter project with recommended settings and linter rules.
3.  Generates starter `pubspec.yaml`, `README.md`, and `CHANGELOG.md` files.
4.  Produces a `DESIGN.md` and `IMPLEMENTATION.md` for your review and approval before any code is written.

```bash
/create-app I want to create a trip planning app
```

### `/refactor`

Starts a structured session to refactor existing code. It helps you plan and execute changes safely and efficiently.

**Process:**
1.  Asks for your high-level refactoring goals and what you want to accomplish.
2.  Offers to create a new `git` branch for the refactoring work, isolating changes.
3.  Generates a `REFACTOR.md` design document detailing the proposed changes.
4.  Creates a phased `REFACTOR_IMPLEMENTATION.md` plan for your review and approval.

```bash
/refactor
```

### `/commit`

Prepares your staged `git` changes for a clean, high-quality commit. It acts as an automated pre-commit hook and message generator.

**Process:**
1.  Runs `dart fix` and `dart format` to clean and format your code.
2.  Executes the Dart analyzer to check for static analysis issues.
3.  Runs your project's test suite to ensure all tests are passing.
4.  Generates a descriptive commit message based on the staged changes for you to review, edit, and approve.

```bash
/commit
```

## ⚙️ Coding Guidelines

This extension enforces a specific set of coding standards to ensure consistency and quality. These rules are defined in the extension's repository:

-   **`flutter.md`**: Contains rules and best practices for writing Dart and Flutter code. These rules are opinionated, and we encourage you to review them to ensure they align with your style.
-   **`override`**: Contains important, high-priority rules that are appended to the end of all prompts to ensure they have the most weight.

## 🐛 Troubleshooting

### Common Issues

1.  **"Command not recognized"**: Ensure the extension is installed correctly and you have restarted the Gemini CLI. Verify the installation with `gemini extensions list`.

2.  **"Gemini CLI version error"**: This extension requires Gemini CLI version 0.4.0 or greater. Check your version with `gemini --version` and update if necessary.

### Filing Issues

If you have feedback, suggestions, or run into issues, please [file an issue on GitHub](https://github.com/flutter/gemini-cli-extension/issues/new/choose).

## 🤝 Contributing

Contributions are welcome! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) guide for more details on how to get started.
