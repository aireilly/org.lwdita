<?xml version="1.0" encoding="UTF-8" ?>
<!--
  DITA to Markdown DITA, fail-closed.

  Template for the entry stylesheet of the `markdown_lossless` transtype. Imports the
  ordinary Markdown transform and layers the lossless modules over it. A later
  import outranks an earlier one:

    dita2markdown.xsl      the base transform
    markdown-lossless-core.xsl         placement of dropped content, the safety net, and
                           the serializer for what the Markdown DITA parser reads
    admonition-mkdocs.xsl  the built-in admonition style
    dita.xsl.markdown.admonition
                           admonition styles that other plug-ins add
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import href="dita2markdown.xsl"/>
  <xsl:import href="markdown-lossless-core.xsl"/>
  <xsl:import href="admonition-mkdocs.xsl"/>
  <dita:extension id="dita.xsl.markdown.admonition" behavior="org.dita.dost.platform.ImportXSLAction" xmlns:dita="http://dita-ot.sourceforge.net"/>

</xsl:stylesheet>
