## **docs/USAGE.md**

# zeP – Usage Guide

zeP is a fast, minimalist package and version manager for Zig.  
It provides easy bootstrapping, dependency management, and running of Zig projects.

---

## Bootstrap a Project

`zep bootstrap` prepares a new project or sets up an existing one with dependencies.

### **Syntax**

```bash
zep bootstrap --zig <zig_version> --pkgs "<package1@version,package2@version,...>"
```

### **Options**

| Option   | Description                                                                                                     |
| -------- | --------------------------------------------------------------------------------------------------------------- |
| `--zig`  | The target Zig version for the project. Installs it if not present, or switches if installed.                   |
| `--pkgs` | Comma-separated list of dependencies with versions. Installs and imports missing packages, links existing ones. |

---

## Running Projects

`zep run` builds and executes your project using the configured dependencies.
Zig build is run under the hood, and the runner automatically finds the latest build.

### **Syntax**

```bash
zep run
```

You can optionally pass arguments to the executed program:

```bash
zep run --target <target-exe> --args <arg1> <arg2> ...
```

---

## CLI Reference

### `bootstrap`

- Sets up project with a specific Zig version and dependencies.
- Example:

```bash
zep bootstrap --zig 0.14.0 --pkgs "clap@0.10.0,zeit@0.7.0"
```

### `new`

- Quick start empty project.
- Example:

```bash
zep new my_project
```

### `run`

- Builds and runs the current project.
- Example:

```bash
zep run
```

---

## Notes

- zeP automatically manages project-specific dependencies under `.zep/`.
- Versions prior to 0.5 were MIT licensed; starting 0.5, the project uses GPLv3.
- Versions prior to 0.8 used zeP as executable name; starting 0.8, executables are named zep (with lowercase P).
- Versions prior to 0.9.0 do not use the semantic version structure.
- Versions prior to 1.0.0 are expected to have bugs, and it is not suggested to use them.
- Versions prior to 1.1.0 are storing their data in a different folder, migration function might not work as expected.
