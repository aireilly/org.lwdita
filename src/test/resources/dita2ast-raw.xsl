<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="xs"
                version="2.0">

  <xsl:import href="ast2markdown.xsl"/>

  <xsl:import href="dita2markdownImpl.xsl"/>
  <xsl:import href="task.xsl"/>
  <xsl:import href="ut-d.xsl"/>
  <xsl:import href="sw-d.xsl"/>
  <xsl:import href="pr-d.xsl"/>
  <xsl:import href="ui-d.xsl"/>
  <xsl:import href="hi-d.xsl"/>
  <xsl:import href="markup-d.xsl"/>
  <xsl:import href="xml-d.xsl"/>
  <xsl:import href="raw-dita.xsl"/>

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
