<?xml version="1.0" encoding="UTF-8"?>
<!--
  Admonition style "mkdocs": the syntax of the Python-Markdown admonition
  extension that MkDocs uses.

      !!! warning "Optional title"
          Content, indented four spaces.

  This file is the model for a style of your own. A style is one template
  in the lossless-admonition mode that matches its own name and returns the text
  of the admonition starting at column 0. The caller indents the result to
  the place of the note in a list or table cell and adds the blank line
  after it.

  The admonition element has:

    @type   note/@type, or note/@othertype when it is a single word
    @title  note/@spectitle, or an @othertype of several words; optional

  The $body parameter is the content of the note as Markdown, at column 0
  and without a trailing line break.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ast="com.elovirta.dita.markdown"
                exclude-result-prefixes="xs ast"
                version="2.0">

  <xsl:template match="admonition[$markdown.admonition.style = 'mkdocs']" mode="lossless-admonition">
    <xsl:param name="body" as="xs:string"/>
    <xsl:text>!!! </xsl:text>
    <xsl:value-of select="@type"/>
    <xsl:if test="normalize-space(@title)">
      <xsl:text> "</xsl:text>
      <xsl:value-of select="replace(normalize-space(@title), '&quot;', '&#x201D;')"/>
      <xsl:text>"</xsl:text>
    </xsl:if>
    <xsl:text>&#xA;</xsl:text>
    <xsl:value-of select="ast:prefix-lines($body, '    ')"/>
  </xsl:template>

</xsl:stylesheet>
