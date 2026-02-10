## **docs/DOCS.md**

# zeP – Docs

zeP has multiple commands, that make your life easier. Most of
it is automated, simple, and clean.

---

### **Package Commands**

#### **Install a package**

```bash
zep install <package-name>@<version> -I (-GH/-GL/-CB/-Z/-L) # installs into local project
```

- Looks in specified registry
- Updates lockfile and build.zig.zon

#### **Uninstall a package**

```bash
zep uninstall <package-name>@<package-version> <install-type> -G -F  # deletes from local project (-G global) (-F force)
```

- Uninstalls package from local project
- Removes from manifest
- Deletes package if not used by any project

#### **Inject package modules**

```bash
zep inject
```

- Asks which modules should get packages injected

#### **Info of a package**

```bash
zep info <package-name>
```

- Returns information about package

#### **List package version**

```bash
zep list <package-name>
```

- Lists available versions of said package
- Includes corresponding zig version

#### **Add a custom package**

```bash
zep custom add <package-name>
```

(if a package is not included in zep.run, you can add your own! [unverified])

- Adds a custom package to customPackages

#### **Remove a custom package**

```bash
zep custom remove <package-name>
```

- Removes a custom package

#### **Purge**

```bash
zep purge
```

- Purges the packages from the local project
- Executes uninstall for all packages installed

#### **Cache**

```bash
zep cache list
```

- Lists cached items

```bash
zep cache clean <package_name?@package_version?>
```

- Cleans the entire cache
- Or a given package

```bash
zep cache size
```

- Returns the size of the current cache
- From Bytes -> Terabytes

---

### **Custom Commands**

```bash
zep cmd add
```

- adds a custom command

```bash
zep cmd run <cmd>
```

- run custom command

```bash
zep cmd remove <cmd>
```

- removes custom command

```bash
zep cmd list
```

- lists all custom commands

---

### **Zig Version Commands**

#### **Install a Zig version**

```bash
zep zig install <version> <target>
```

- Target defaults back depending on system

#### **List installed Zig versions**

```bash
zep zig list
```

#### **Switch active Zig version**

```bash
zep zig switch <version> <target>
```

- Target defaults back depending on system

#### **Uninstall a Zig version**

```bash
zep zig uninstall <version>
```

#### **Upgrade Zig**

```bash
zep zig upgrade
```

#### **Zig Cache**

```bash
zep zig cache [list/size/clean]
```

### **Zep Commands**

#### **Install a zeP version**

```bash
zep self install <version>
```

#### **List installed zeP versions**

```bash
zep self list
```

#### **Switch zeP version** [DO NOT USE FOR zeP => (soft-lock)]

```bash
zep self switch <version>
```

#### **Uninstall a zeP version**

```bash
zep self uninstall <version>
```

#### **Uprade zeP**

```bash
zep self upgrade
```

#### **zeP Cache**

```bash
zep self cache [list/size/clean]
```

---

### **PreBuilt Commands**

#### **Build a preBuilt**

```bash
zep prebuilt build [name] (target)
```

- Builds a prebuilt with a given name (will overwrite if exists)
- Target falls back to ".", if not specified

#### **Use a preBuilt**

```bash
zep prebuilt use [name] (target)
```

- Uses a prebuilt (if exists)
- Target falls back to ".", if not specified

#### **Delete a preBuilt**

```bash
zep prebuilt delete [name]
```

- Deletes a prebuilt (if exists)

---

### **Build Commands**

```bash
zep build
```

- Runs build command

```bash
zep run --target <target-exe> --args <args>
```

- Builds and runs your executeable, including the args

---

## **Configuration Files**

### **`zep.lock`**

Your project’s declared dependencies.
Exact versions, hashes, and metadata of installed packages.

#### **Init project**

```bash
zep init
```

- Adds zep.lock and .zep/ with starter values
- Inits own Zig project, with pre-set values

#### **zep.lock file**

```bash
zep config
```

- Allows for modification of data within zep.lock using terminal
- More reliable as changes will get automatically reflected onto .lock

#### **Doctor check**

```bash
zep doctor (--fix)
```

- Checks config files, detect issues
- Fixes issues automatically if told to

### **Authentication**

```bash
zep auth register
```

- Register via email, username and password

```bash
zep auth login
```

- Login into zep.run

```bash
zep auth logout
```

- Logouts and deletes local token

```bash
zep auth whoami
```

- Displays user data

### **Package**

```bash
zep package create
```

- Creates Package

```bash
zep package list
```

- Lists available packages

```bash
zep package delete
```

- Deletes selected package (if valid)

### **Release**

```bash
zep release create
```

- Creates New Release

```bash
zep release list
```

- Lists available releases (from selected package)

```bash
zep release delete
```

- Deletes selected release (if valid)

---

For more information, and explanations, run

```
$ zep help <command?>
```
