# Click <uicontrol>Save</uicontrol> {#raw-dita}

## Domain phrases {.section}

Click <uicontrol>File</uicontrol>, then <menucascade><uicontrol>Edit</uicontrol><uicontrol>Preferences</uicontrol></menucascade>.

Edit <filepath>/etc/\*.conf</filepath> and set <varname>my\_var\_name</varname>.

Run <cmdname>grep</cmdname>, type <userinput>yes</userinput>, and read <systemoutput>OK</systemoutput>.

Call <apiname>getValue\(\)</apiname> in <xmlelement>codeblock</xmlelement> with <codeph>run <varname>target</varname></codeph>.

A <term>term</term>, a <cite>Book</cite>, a <q>quote</q>, a <keyword>keyword</keyword>, <tm tmtype="reg">Acme</tm>, and <tt>teletype</tt>.

## Attributes {.section}

A paragraph with an ID.
{#para-id}

A paragraph with classes.
{.draft .wide}

<p id="p.dotted">
An ID that no attribute block holds.
</p>

Inline **bold**{#bold-id}, *italic*{.em} and `code`{#code-id}.

Install <keyword keyref="product"></keyword> or <ph keyref="product">the product</ph> with <ph id="ph-id">a phrase</ph>.

-   <p id="li-para">
    A list paragraph.
    </p>


> A quoted paragraph.
> {#lq-para}

## Raw blocks {.section}

<note type="warning" id="note-id">
<p>Install <keyword keyref="k"></keyword> first, see <xref href="other.dita">Other</xref>.</p><codeblock xml:space="preserve">first&#10;&#10;third</codeblock>
</note>

<lq id="lq-id">
<p>Quoted.</p>
</lq>

<ul>
<li id="java">Install Java.</li><li>Install Maven.</li>
</ul>

<ol outputclass="steps">
<li>One.</li><li>Two.</li>
</ol>

<sl>
<sli id="sli-id">Simple.</sli>
</sl>

<simpletable>
<sthead><stentry>Head</stentry></sthead><strow id="row-id"><stentry>Cell</stentry></strow>
</simpletable>

<fig id="fig-id">
<title>Figure</title><p>Figure body.</p>
</fig>

<div outputclass="box">
<p>In a division.</p>
</div>

## Raw blocks in containers {.section}

-   Item.

    <note id="li-note">
    <p>In a list.</p>
    </note>


!!! tip
    In an admonition.
    {#adm-para}

    <ul>
    <li id="adm-li">Admonition item.</li>
    </ul>

> <note id="lq-note">
> <p>In a quote.</p>
> </note>

| Action | Value |
|---|---|
| Pick <uicontrol>OK</uicontrol> | <ph outputclass="a&#124;b">Piped</ph> |

