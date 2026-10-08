# Lightweight DITA for DITA-OT [![Test](https://github.com/jelovirt/org.lwdita/actions/workflows/test.yml/badge.svg)](https://github.com/jelovirt/org.lwdita/actions/workflows/test.yml)

The DITA-OT LwDITA plug-in supersedes the previously released [Markdown
plug-in for DITA-OT](https://github.com/jelovirt/dita-ot-markdown) and
adds additional features to support Lightweight DITA.

> **Note**
> The LwDITA plug-in is included in DITA Open Toolkit 3.0 and
newer.

It contains:

- a custom SAX parser for Markdown and HTML to allow using Markdown and HDITA
  as source document formats,
- and a transtype to generate Markdown from DITA source.

## Markdown source document formats

Markdown-based source files must use a subset of Markdown constructs for
compatibility with DITA content models.

Two different Markdown source formats are supported:

- [Markdown DITA](https://github.com/jelovirt/org.lwdita/wiki/Markdown-DITA-syntax)
- [MDITA (LwDITA)](https://github.com/jelovirt/org.lwdita/wiki/MDITA-syntax)

For a comparison of these two formats, see [Format comparison](https://github.com/jelovirt/org.lwdita/wiki/Format-comparison) in the LwDITA Wiki.

## Usage

### Using Markdown-based and HDITA files as input

Markdown-based or HTML DITA topics can only be used by linking to them in
map files.

```xml
<map>
  <!-- Markdown DITA -->
  <topicref href="test1.md" format="md"/>
  <topicref href="test1.md" format="markdown"/>

  <!-- MDITA -->
  <topicref href="test2.md" format="mdita"/>

  <!-- HDITA -->
  <topicref href="test3.html" format="hdita"/>
</map>
```

The `format` attribute value must be set to the values shown above in order
to recognize files as Markdown DITA, MDITA, or HDITA, respectively; the file
extension is not used to recognize format.

### Generating Markdown output

The DITA-OT LwDITA plug-in extends the DITA Open Toolkit with additional
output formats *(transformation types)* that can be used to publish DITA
content as Markdown.

- To publish Markdown DITA files, use the `markdown` transtype.

- To generate [GitHub Flavored
  Markdown](https://help.github.com/categories/writing-on-github/)
  files, use the `markdown_github` transtype.

- To publish GitHub Flavored Markdown and generate a `SUMMARY.md` table
  of contents file for publication via
  [GitBook](https://www.gitbook.com), use the `markdown_gitbook`
  transtype.

## Selecting a topic type with `$schema`

A `$schema` key in the YAML front matter tells the plug-in which DITA topic
type to produce. It must be the **first** key, on the line directly after the
opening `---`; anywhere else it is ignored without warning and the file
converts as a generic topic.

| Type | XSD form | RELAX NG form |
|------|----------|---------------|
| Topic | `urn:oasis:names:tc:dita:xsd:topic.xsd` | `urn:oasis:names:tc:dita:rng:topic.rng` |
| Concept | `urn:oasis:names:tc:dita:xsd:concept.xsd` | `urn:oasis:names:tc:dita:rng:concept.rng` |
| Task | `urn:oasis:names:tc:dita:xsd:task.xsd` | `urn:oasis:names:tc:dita:rng:task.rng` |
| Reference | `urn:oasis:names:tc:dita:xsd:reference.xsd` | `urn:oasis:names:tc:dita:rng:reference.rng` |
| Map | `urn:oasis:names:tc:dita:xsd:map.xsd` | `urn:oasis:names:tc:dita:rng:map.rng` |

The MDITA profiles are selected the same way, with
`urn:oasis:names:tc:mdita:xsd:topic.xsd`, its `:extended:` synonym, or
`urn:oasis:names:tc:mdita:core:xsd:topic.xsd`. They parse as Lightweight DITA,
so they produce no specialization: every H2 becomes a `<section>`, `{...}`
attribute blocks are not parsed, and the element set is reduced.

> **Note**
> The infix and the suffix have to match. `xsd` goes with `.xsd` and `rng`
> goes with `.rng`. A mixed value such as
> `urn:oasis:names:tc:dita:xsd:task.rng` is not registered, and the plug-in
> reports it before falling back to the default parser:
>
> ```
> [DOTJ088E] XML parsing error: Markdown schema
> urn:oasis:names:tc:dita:xsd:task.rng not recognized,
> using default Markdown parser
> ```
>
> For a task the visible symptom usually arrives later, as an error saying that
> a heading "can't be a section here" because the heading above it opened a
> nested topic, since the topic is no longer a task and its section headings
> become nested topics.

A class on the H1 heading, `# Installing the CLI {.task}`, is the older way to
select a type and remains equivalent.

The topic `@id` comes from the `id:` key, or from a slug of the title when
`id:` is absent. Set it explicitly for any topic that is linked to, so
renaming the title does not change the id.

In concept and reference topics, `##` starts a `<section>`. Sections don't
nest, so `###` is an error. Link to a section as `file.md#topic-id/heading`.
Generic topics and tasks are unchanged: an H2 there still opens a nested topic,
except for the task section titles listed under [Task](#task).

### Concept

```markdown
---
$schema: urn:oasis:names:tc:dita:xsd:concept.xsd
id: about-containers
---

# About containers

A container packages an application with its dependencies so it runs the same everywhere.

Containers share the host kernel, so they start faster and use less memory than virtual machines.

!!! note
    A container image is a template; a container is a running instance of one.

## Limitations

A container does not isolate the kernel, so it is not a security boundary.
```

The title becomes `<title>`, the first paragraph `<shortdesc>`, the rest
`<conbody>`, and the admonition a `<note type="note">`. The H2 becomes
`<section id="limitations">` inside `<conbody>`, which another topic links to
as `about-containers.md#about-containers/limitations`.

### Task

````markdown
---
$schema: urn:oasis:names:tc:dita:xsd:task.xsd
id: installing-the-cli
---

# Installing the CLI

Install the CLI to manage resources from a terminal.

## Prerequisites

-   Administrator access on the workstation.
-   `curl` on the `PATH`.

## About this task

The installer downloads a signed binary and places it in `/usr/local/bin`.

## Procedure

1.  Download the archive:

    ```bash
    curl -LO https://example.com/cli.tar.gz
    ```

2.  Extract and install it:

    ```bash
    tar xzf cli.tar.gz && sudo mv cli /usr/local/bin/
    ```

## Verification

Run `cli --version` and confirm it prints the version you installed.

## Next steps

Authenticate with `cli login`.
````

This produces `<prereq>`, `<context>`, `<steps>` with a `<step>` per list item,
`<result>`, and `<postreq>`. The section headings are mapped by the
`implicit-task-sections` feature, which `plugin.xml` enables for the `md` and
`markdown` formats. The default titles are:

| Heading | Element |
|---------|---------|
| Prerequisites | `<prereq>` |
| About this task | `<context>` |
| Procedure, Steps | the marker for `<steps>`; the heading itself maps to no element |
| Verification | `<result>` |
| Next steps | `<postreq>` |

Any other H2 in a task becomes a nested topic rather than a section, so keep
examples and troubleshooting inside these sections or in a separate topic.
Configure the titles per section with
`setProperty("http://lwdita.org/sax/properties/implicit-task-sections/context", List.of("about this task"))`.

The first paragraph after the title is the `<shortdesc>`, so it coexists with
an `About this task` section. A **second** paragraph before the first heading
becomes a `<context>` of its own, which together with `About this task` gives
two `<context>` elements and fails the task DTD.

#### Lists and tables inside a step

A list nested inside a step becomes `<substeps>`, whether it is ordered or
unordered: `implicit-substeps` defaults to true. `implicit-choices` and
`implicit-choicetable` default to false and `plugin.xml` does not enable
them, so a nested unordered list is not `<choices>` and a table inside a step
stays a plain `<table>`.

Select those elements per block with an outputclass instead:

````markdown
1.  Choose one:

    *   Keep the defaults
    *   Configure it by hand
    {.choices}

2.  Pick a plan:

    | Option | Description |
    |--------|-------------|
    | Fast   | Quick setup |
    {.choicetable}
````

Turn the implicit mappings on for a whole build with
`setFeature("http://lwdita.org/sax/features/implicit-choices", true)` and
`setFeature("http://lwdita.org/sax/features/implicit-choicetable", true)`.
Enabling `implicit-choices` changes what every nested unordered list produces,
because the choices branch is tried before the substeps one.

### Reference

```markdown
---
$schema: urn:oasis:names:tc:dita:xsd:reference.xsd
id: cli-options
---

# CLI options

The following options apply to every `cli` subcommand.

| Option | Argument | Description |
|--------|----------|-------------|
| `--config` | path | Configuration file to read. |
| `--verbose` | none | Print each request and response. |

## Example {.example}

    cli --config ./cli.yaml --verbose status
```

The table becomes a CALS `<table>` inside `<refbody>`. In the MDITA profiles it
would be a `<simpletable>` instead. An H2 opens a `<section>` in `<refbody>`,
and `{.example}` an `<example>`.

## Requirements

| LwDITA plug-in | DITA-OT  | Java |
|----------------|----------|------|
| ≤ 2.5          | 2.4      | 1.8  |
| ≥ 3.0          | 3.4      | 1.8  |
| ≥ 4.0          | 3.4      | 11   |
| ≥ 5.2          | 3.4 [^1] | 11   |

[^1]: Support MDITA map requires DITA-OT version 4.1.

## Install

1.  Run the plug-in installation command:

    On DITA-OT version 3.5 and newer:

    ``` shell
    $ dita install org.lwdita
    ```

    On DITA-OT version 3.2–3.4:

    ``` shell
    $ dita --install org.lwdita
    ```

    On DITA-OT version 3.1 and older:

    ``` shell
    $ dita --install https://github.com/jelovirt/org.lwdita/releases/download/2.3.2/org.lwdita-2.3.2.zip
    ```

The `dita` command line tool requires no additional configuration;
running DITA-OT using Ant requires adding plug-in contributed JAR files
to the `CLASSPATH` with e.g. `-lib plugins/org.lwdita`.

## Build

To build the DITA-OT Markdown plug-in from source:

1.  Run the Gradle distribution task to generate the plug-in
    distribution package:

    ``` shell
    ./gradlew dist
    ```

    The distribution ZIP file is generated under `build/distributions`.

## Release

To release and build distribution:

1.  Tag release in `master` branch using semantic version as tag name,
    e.g. `1.2.3`.

    > **Note**
    > GitHub disables Actions on a new fork until they are enabled once in
    > the repository's Actions tab. Until then a pushed tag produces no run
    > at all, and the ZIP has to be built with `./gradlew dist` and attached
    > by hand.

    [GitHub Actions](.github/workflows/dist.yml) will create
    * a distribution ZIP and upload it to GitHub Release for the tag,
    * a JAR release that is published to [github.com/jelovirt/org.lwdita/packages](https://github.com/jelovirt/org.lwdita/packages/),
    * a pull request to [github.com/dita-ot/registry](https://github.com/dita-ot/registry)
to update the release to DITA-OT plug-in registry. This last step runs only
on `jelovirt/org.lwdita`; a fork gets the ZIP and the JAR, under its own
repository name.

## Donating

Support this project and others by
[@jelovirt](https://github.com/jelovirt) via [GitHub
Sponsors](https://github.com/sponsors/jelovirt).

## License

DITA-OT LwDITA is licensed for use under the [Apache License
2.0](http://www.apache.org/licenses/LICENSE-2.0).
