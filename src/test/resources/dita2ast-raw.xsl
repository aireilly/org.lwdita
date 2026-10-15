<?xml version="1.0" encoding="UTF-8"?>
<!-- DITA to AST through the shipped Markdown stylesheet, with raw DITA
     passthrough enabled. -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

  <xsl:import href="dita2markdown_template.xsl"/>

  <xsl:param name="raw-dita" select="'yes'"/>

  <xsl:output method="xml" encoding="UTF-8"/>

  <xsl:template match="/">
    <xsl:variable name="ast" as="node()">
      <xsl:apply-templates/>
    </xsl:variable>
    <xsl:variable name="ast-flat" as="node()">
      <xsl:apply-templates select="$ast" mode="flatten"/>
    </xsl:variable>
    <xsl:apply-templates select="$ast-flat" mode="ast-clean"/>
  </xsl:template>

</xsl:stylesheet>
