# Skills Management

This context describes how a developer discovers and makes agent skills available on one Mac.

## Language

**Skill**:
A reusable instruction set identified by a `SKILL.md` file and installed for one or more agents.
_Avoid_: Plugin, extension, command

**Source**:
The repository, URL, or local path from which one or more skills can be obtained.
_Avoid_: Package, store item

**Agent**:
A supported coding tool that can consume installed skills.
_Avoid_: Client, runtime, target application

**Target Agent**:
An agent explicitly selected to receive a skill during installation.
_Avoid_: Destination, integration

**Global Skill**:
A skill installed at user scope and available independently of any one project.
_Avoid_: System skill, shared skill

**Installed Skill**:
A global skill currently available to at least one agent on this Mac.
_Avoid_: Download, package

**Discovery Result**:
A skill returned by the official skills directory while browsing or searching.
_Avoid_: Catalog item, recommendation

