# Bashly Documentation (Offline Reference)

---

## Overview

Bashly is a framework for building modern, maintainable, and user-friendly CLI tools in Bash. It uses a YAML configuration file to define commands, arguments, options, and help text, and generates a robust Bash script with built-in parsing, validation, and help output.

---

## Installation

### Using RubyGems
```sh
gem install bashly
```

### Using Homebrew (macOS/Linux)
```sh
brew install dannyben/bashly/bashly
```

### Docker
```sh
docker run -it --rm -v "$PWD:/app" dannyben/bashly bashly generate
```

---

## Getting Started

1. **Initialize a new project:**
   ```sh
   bashly init
   ```
   - Creates `bashly.yml` and `src/` directory with starter files.
2. **Edit `bashly.yml`:**
   - Define CLI structure, commands, options, arguments, help, examples, environment variables, dependencies, and more.
   - See full configuration reference below for all available keys and options.
3. **Generate the script:**
   ```sh
   bashly generate
   ```
   - Produces a `cli` Bash script in the project root.
   - Regenerate after any config or source change.
4. **Run your CLI:**
   ```sh
   ./cli [command] [options]
   ```
   - All parsing, validation, and help output is handled automatically.

---

## bashly.yml Structure (Exhaustive Reference)

### Top-level keys
- `name`: Name of the CLI (string)
- `help`: Top-level help text (string)
- `version`: Version string (string)
- `commands`: List of subcommands (array)
- `args`: Global arguments (array)
- `flags`: Global flags (array)
- `env`: Environment variables (array)
- `dependencies`: Required external commands (array)
- `examples`: Usage examples (array)
- `extends`: List of YAML files to merge (array)

### Command keys
- `name`: Command name (string)
- `help`: Command help text (string)
- `args`: Arguments for this command (array)
- `flags`: Flags for this command (array)
- `examples`: Usage examples (array)
- `env`: Environment variables (array)
- `dependencies`: Required external commands (array)
- `extends`: List of YAML files to merge (array)
- `commands`: Nested subcommands (array)
- `default`: If true, this command is the default (boolean)
- `hidden`: If true, this command is hidden from help (boolean)
- `strict`: If true, disables unknown arguments (boolean)

### Argument keys
- `name`: Argument name (string)
- `help`: Help text (string)
- `required`: If true, argument is required (boolean)
- `default`: Default value (string)
- `choices`: Allowed values (array)
- `multiple`: If true, accepts multiple values (boolean)
- `depends_on`: List of flags/args that must be present (array)
- `conflicts_with`: List of flags/args that must NOT be present (array)
- `filter`: Name of filter to apply (string)
- `env`: Name of environment variable to use as fallback (string)

### Flag keys
- `long`: Long flag (e.g., `--verbose`)
- `short`: Short flag (e.g., `-v`)
- `name`: Name for referencing in scripts (string)
- `help`: Help text (string)
- `required`: If true, flag is required (boolean)
- `default`: Default value (string)
- `choices`: Allowed values (array)
- `multiple`: If true, accepts multiple values (boolean)
- `depends_on`: List of flags/args that must be present (array)
- `conflicts_with`: List of flags/args that must NOT be present (array)
- `filter`: Name of filter to apply (string)
- `env`: Name of environment variable to use as fallback (string)
- `hidden`: If true, flag is hidden from help (boolean)

### Environment Variable keys
- `name`: Variable name (string)
- `help`: Help text (string)
- `required`: If true, must be set (boolean)
- `default`: Default value (string)
- `choices`: Allowed values (array)

### Dependency keys
- `name`: Command name (string)
- `help`: Help text (string)
- `url`: URL for installation instructions (string)

### Example (Exhaustive)
```yaml
name: mycli
help: My CLI tool
version: 1.0.0
examples:
  - mycli greet John --shout
  - mycli help
env:
  - name: MYCLI_DEBUG
    help: Enable debug mode
    default: "0"
    choices: ["0", "1"]
commands:
  - name: greet
    help: Greet someone
    args:
      - name: name
        help: Name to greet
        required: true
        filter: string
    flags:
      - long: --shout
        short: -s
        name: shout
        help: Shout the greeting
        default: "false"
        choices: ["true", "false"]
        filter: bool
      - long: --lang
        name: lang
        help: Language
        choices: [en, es, fr]
        default: en
    env:
      - name: GREET_STYLE
        help: Greeting style
        default: "formal"
    dependencies:
      - name: cowsay
        help: Required for fun output
        url: https://github.com/tnalpgge/rank-amateur-cowsay
    examples:
      - mycli greet John --shout
      - mycli greet Alice --lang fr
    commands:
      - name: polite
        help: Greet politely
        args:
          - name: name
            required: true
```

---

## Command Features (Exhaustive)

- **Nested commands:** Unlimited depth, each with its own args, flags, help, etc.
- **Arguments:**
  - Required/optional, default values, multiple values, choices, filters, environment fallback, dependencies/conflicts.
- **Flags:**
  - Short/long, required/optional, default, multiple, choices, filters, environment fallback, dependencies/conflicts, hidden.
- **Environment variables:**
  - Used for config, can be required, have defaults, choices, and help text.
- **Dependencies:**
  - Check for required binaries before running command. If missing, error with help and URL.
- **Help text:**
  - Auto-generated for all commands, args, flags, env, dependencies, and examples. Customizable per command.
- **Examples:**
  - Shown in help output, can be global or per command.
- **Extending config:**
  - Use `extends:` to merge multiple YAML files. Useful for large/complex CLIs.
- **Strict mode:**
  - If `strict: true`, unknown arguments/flags cause an error.
- **Hidden commands/flags:**
  - If `hidden: true`, not shown in help output.
- **Default command:**
  - If `default: true`, runs when no command is specified.

---

## Advanced Features (Exhaustive)

### Validations
- `required`: Must be provided.
- `default`: Value used if not provided.
- `choices`: Only allowed values.
- `multiple`: Accepts multiple values (array).
- `depends_on`: Requires other flags/args to be present.
- `conflicts_with`: Fails if other flags/args are present.

### Filters
- `int`: Integer value
- `float`: Floating point value
- `bool`: Boolean value (`true`/`false`, `1`/`0`, `yes`/`no`)
- `file`: Must be a file
- `existing_file`: Must be an existing file
- `dir`: Must be a directory
- `existing_dir`: Must be an existing directory
- `path`: Any path
- `string`: Any string

### Hooks
- Place scripts in `hooks/`:
  - `pre_COMMAND.sh`: Runs before command
  - `post_COMMAND.sh`: Runs after command
  - `pre_all.sh`/`post_all.sh`: Runs before/after any command
- Scripts receive all arguments and environment variables.
- Exit nonzero to abort command.

### Shell Completions
- Generate completions for Bash, Zsh, Fish:
  ```sh
  bashly completions bash > completions.bash
  bashly completions zsh > completions.zsh
  bashly completions fish > completions.fish
  ```
- Place completion files in appropriate shell config directory.

### Split Config
- Use `extends:` to split config into multiple YAML files for modularity.
- Example:
  ```yaml
  extends:
    - base.yml
    - commands/greet.yml
  ```

### ERB Support
- Use ERB templating in YAML for dynamic config.
- Example:
  ```yaml
  help: "Generated on <%= Time.now %>"
  ```

### Extensible Scripts
- Place custom scripts in `src/commands/` to override generated command logic.
- Place shared functions in `src/lib/` and include with `@lib`.
- Use `@include` to include other scripts.
- Example:
  ```bash
  # src/commands/greet.sh
  @lib helpers.sh
  echo "Hello $ARG_NAME"
  ```

### Rendering
- Use `bashly render` to preview the generated script without writing to disk.
- Example:
  ```sh
  bashly render > preview.sh
  ```

---

## Libraries (Exhaustive)

- **Reusable logic:** Place shared functions in `src/lib/` and include with `@lib`.
- **Community libraries:** See [bashly.dev/libraries](https://bashly.dev/libraries) for examples.
- **Usage:**
  - `@lib helpers.sh` in any command script to include `src/lib/helpers.sh`.
  - Use `@include` to include arbitrary scripts.

---

## Testing (Exhaustive)

- Use [Bats](https://bats-core.readthedocs.io/) for Bash testing.
- Example test:
  ```sh
  @test "greet outputs greeting" {
    run ./cli greet John
    [ "$status" -eq 0 ]
    [ "$output" = "Hello John" ]
  }
  ```
- Place tests in `test/` directory.
- Use `bats test/` to run all tests.
- Test all commands, flags, error cases, and help output.

---

## Configuration Reference (Exhaustive)

### Top-level keys
- `name`, `help`, `version`, `commands`, `args`, `flags`, `env`, `dependencies`, `examples`, `extends`

### Command keys
- `name`, `help`, `args`, `flags`, `examples`, `env`, `dependencies`, `extends`, `commands`, `default`, `hidden`, `strict`

### Argument/Flag keys
- `name`, `help`, `required`, `default`, `choices`, `multiple`, `depends_on`, `conflicts_with`, `filter`, `env`, `long`, `short`, `hidden`

### Environment Variable keys
- `name`, `help`, `required`, `default`, `choices`

### Dependency keys
- `name`, `help`, `url`

---

## Useful CLI Commands (Exhaustive)

- `bashly init` — Initialize project (creates config and src/)
- `bashly generate` — Generate CLI script from config and src/
- `bashly add command NAME` — Add a new command (updates config and creates stub script)
- `bashly add arg NAME` — Add an argument to the last command
- `bashly add flag NAME` — Add a flag to the last command
- `bashly completions [shell]` — Generate completions for Bash, Zsh, Fish
- `bashly render` — Preview generated script
- `bashly upgrade` — Upgrade Bashly to latest version
- `bashly config` — Show Bashly config and environment
- `bashly help` — Show Bashly help
- `bashly version` — Show Bashly version

---

## Resources

- [Official Docs](https://bashly.dev/docs)
- [Configuration Reference](https://bashly.dev/reference/configuration)
- [Advanced Topics](https://bashly.dev/docs/advanced)
- [Libraries](https://bashly.dev/libraries)
- [GitHub](https://github.com/DannyBen/bashly)

---

## Tips (Exhaustive)

- Use `bashly generate --force` to overwrite existing scripts.
- Place custom logic in `src/commands/` or `src/lib/`.
- Use hooks for pre/post command logic.
- Use ERB for dynamic YAML.
- Use split config for large projects.
- Use `@lib` and `@include` for code reuse.
- Use `hidden: true` for experimental commands/flags.
- Use `strict: true` to enforce argument/flag validation.
- Use `default: true` for default commands.
- Use `bats` for automated testing.
- Use `bashly render` to preview scripts before generating.
- Use `bashly config` to debug Bashly environment.

---

## Example Project Structure (Exhaustive)

```
mycli/
  bashly.yml
  src/
    commands/
      greet.sh
      polite.sh
    lib/
      helpers.sh
      logger.sh
    hooks/
      pre_greet.sh
      post_greet.sh
  test/
    greet.bats
  cli
```

---

# Docker Command Migration

The following Docker management scripts have been migrated from standalone Bash scripts in `bin/` to Bashly-based CLI commands:

- `build` → `src/docker_build_command.sh`
- `push` → `src/docker_push_command.sh`
- `reinitdb` → `src/docker_reinitdb_command.sh`

Each command now benefits from Bashly's argument parsing, help output, and maintainable structure. See the CLI help or the command files for details.

---

## Docker Command Migration

### build
- Migrated logic from `bin/build.sh` to `src/docker_build_command.sh`.
- Handles Docker image build for the project, using Bashly argument/flag conventions.

### push
- Migrated logic from `bin/push.sh` to `src/docker_push_command.sh`.
- Pushes the built Docker image to the configured registry.

### reinitdb
- Migrated logic from `bin/reinitdb.sh` to `src/docker_reinitdb_command.sh`.
- Reinitializes the PostgreSQL database volume/container as per the original script.

All Docker-related commands are now available via the Bashly CLI, with argument/flag handling and help output managed by Bashly. See the CLI help for usage details.
