# Raw DITA Test {#raw-dita-test}

Click <uicontrol>File</uicontrol> to open.

Navigate <menucascade><uicontrol>File</uicontrol><uicontrol>Save</uicontrol></menucascade> to save.

The file <filepath>/etc/hosts</filepath> contains entries.

Run <cmdname>grep</cmdname> to search.

Set <varname>MY_VAR</varname> to configure.

Regular **bold** and *italic* and `code` stay as Markdown.

Superscript <sup>2</sup> test.

## Table with domain elements { .section}

|Action|Element|Path|
|------|-------|----|
|Click <uicontrol>OK</uicontrol>|Run <cmdname>make</cmdname>|<filepath>/usr/bin</filepath>|
|Press <uicontrol>Enter</uicontrol>|**Bold cell**|*Italic cell*|

## Lists with domain elements { .section}

-   Click <uicontrol>Save</uicontrol> to save the file.
-   Edit <filepath>/etc/config.yaml</filepath> to configure.
-   Run <cmdname>deploy</cmdname> with <varname>TARGET</varname>.

1.  Open <menucascade><uicontrol>Edit</uicontrol><uicontrol>Preferences</uicontrol></menucascade>.
2.  Set the <varname>HOME</varname> variable.
3.  Use **bold** and `code` normally.

## Definition list with domain elements { .section}

<uicontrol>Save</uicontrol>
:   Saves the current file to <filepath>/tmp/output</filepath>.

<cmdname>grep</cmdname>
:   Searches for <varname>PATTERN</varname> in the input.

## Note with domain elements { .section}

**Warning:** Do not modify <filepath>/etc/passwd</filepath> directly. Use <cmdname>usermod</cmdname> instead.

## Blockquote with domain elements { .section}

> Always run <cmdname>backup</cmdname> before modifying <filepath>/etc/fstab</filepath>.

## ID and reference preservation { .section}

<p id="reusable-para">This paragraph is a conref target.</p>

Click <b id="reuse-bold">Save</b> to continue.

<p conref="common.dita#shared/install-note"></p>

Install <keyword keyref="product-name"></keyword> first.

<note type="warning" id="install-warning">Back up your data before upgrading.</note>

<p outputclass="draft">This paragraph has a custom class.</p>

## List with ID on item { .section}

<ul>
        <li id="prereq-java">Install Java 11 or later.</li>
        <li>Install Maven 3.8 or later.</li>
      </ul>

## Mixed inline complexity { .section}

Use <cmdname>ssh</cmdname> to connect, then **navigate** to <filepath>/var/log</filepath> and run `tail -f syslog`.

The <uicontrol>Status</uicontrol> field shows <systemoutput>OK</systemoutput> when ready.

Type <userinput>yes</userinput> to confirm.

