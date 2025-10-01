# Project Overview

This repository contains a Gemini CLI extension for facilitating Flutter and Dart development. The extension provides a set of commands to streamline common development tasks, including project creation, modification, and committing code. It enforces a set of coding standards and best practices for building high-quality Flutter and Dart applications.

The core of this extension is the `flutter.md` context file, which provides a comprehensive set of rules and guidelines for the AI model. These guidelines cover everything from project structure and coding style to state management and testing.

The extension also includes a set of commands defined in `.toml` files within the `commands` directory. These commands provide a structured way to interact with the AI model for tasks such as creating new apps, modifying existing code, and preparing changes for commit.

## Building and Running

This is a Gemini CLI extension, and as such, it is not "built" or "run" in the traditional sense. Instead, it is installed and used within the Gemini CLI environment.

To install this extension, run the following command:

```bash
gemini extensions install --source https://github.com/flutter/gemini-cli-extension.git
```

To update the extension:

```bash
gemini extensions update flutter
```

To uninstall the extension:

```bash
gemini extensions uninstall flutter
```
