## **docs/PUBLISH.md**

## Publishing a zeP Package

### **Authenticate**

\$ zep auth login
--- LOGIN MODE ---

> Enter email: ...
> Enter password: ...

### **Register**

If you do not have a zeP account, register very easily;

\$ zep auth register
--- Register MODE ---

> Enter username*: ...
> Enter email*: ...
> Enter password*: ...
> Repeat password*: ...

...

> Enter code: ...

After the verification, you should be authenticated by default.

## **Publish Package**

\$ zep package create
--- CREATING PACKAGE MODE ---

> Name\*: ...
> Description: ...
> ...

A package by default, is not installable. Adding your first release however, will enable you
to install your package;

\$ zep release create
--- CREATING RELEASE MODE ---

Select Package target:

- [0] Test

TARGET >> 0
Selected: Test

> [Version] Release*: ...
> Zig Version*: ...
> Root File\*: ...

...

With that, your package is now available online, for everybody!
