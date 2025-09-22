# Flutter AI Guidance

A repository of guidance for AI agents building Flutter and Dart code.

## Status: Highly Experimental

This is an experimental repository, which means the things will change
(sometimes drastically). Feedback very welcome!

This project is intended for demonstration purposes only. It is not
intended for use in a production environment.

## Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md)

## Flutter Extension for Gemini CLI

This extension provides a set of commands to help you work with Dart and Flutter projects.
It will be installed in your ~/.gemini/extensions directory.

## Installation

First, make sure you are using Gemini CLI 0.4.0 or greater.
You can check your version of Gemini CLI this way: `gemini --version`.

Now install the extension:

```shell-command
gemini extensions install --source https://github.com/flutter/gemini-cli-extension.git
```

Once installed, run this to update it:

```shell-command
gemini extensions update flutter
```

To uninstall it:

```shell-command
gemini extensions uninstall flutter
```

## Rules

The [flutter.md](./flutter.md) file contains a bunch of rules for writing Dart code.
Some are very opinionated, so you should probably review them and make sure they
agree with your style.

The [override](./override) file contains some rules that are appended to the end
of all of Gemini's rules so that they have more weight.

## Available Commands

This extension adds some commands, all of which can be run with our without the
"flutter:" prefix (as long as there isn't a name collision with another extension).

### `/start` (or `/flutter:start` if you have more than one start command)

Initializes the agent to work on Dart code. It will summarize the coding guidelines,
documentation rules, and the tools it has available for Dart development. Use this
command at the beginning of a session to ensure the agent is primed with the correct context.

### `/create-app` (or `/flutter:create-app` if you have more than one create-app command)

Starts the process of creating a new Dart or Flutter package. The agent will:

1. Ask for the package's purpose, details, and location.
2. Create a new project with recommended settings, including linter rules.
3. Set up the initial `pubspec.yaml`, `README.md`, and `CHANGELOG.md`.
4. Create a detailed `DESIGN.md` and `IMPLEMENTATION.md` for your review and approval
   before writing code.

This command is ideal for bootstrapping a new project with best practices from the start.

### `/refactor` (or `/flutter:refactor` if you have more than one refactor command)

Initiates a guided refactoring session for existing code. The agent will:

1. Ask for the refactoring goals and what you want to accomplish.
2. Offer to create a new branch for the refactoring work.
3. Generate a `REFACTOR.md` design document outlining the proposed changes.
4. Create a detailed, phased `REFACTOR_IMPLEMENTATION.md` plan for your review and approval.

This command helps structure complex refactoring tasks, ensuring they are well-planned
and executed.

### `/commit` (or `/flutter:commit` if you have more than one commit command)

Prepares your current changes for a git commit. The agent will:

1. Run `dart fix` and `dart format` to clean up the code.
2. Run the analyzer to check for any issues.
3. Run tests to ensure everything is passing.
4. Generate a descriptive commit message based on the changes for you to review and approve.

This command helps maintain code quality and consistency in your commit history.
