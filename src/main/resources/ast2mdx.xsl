<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="component" mode="ast">
    <xsl:text>&lt;</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:for-each select="prop">
      <xsl:text> </xsl:text>
      <xsl:value-of select="@name"/>
      <xsl:text>="</xsl:text>
      <xsl:value-of select="@value"/>
      <xsl:text>"</xsl:text>
    </xsl:for-each>
    <xsl:text>&gt;</xsl:text>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:call-template name="process-inline-contents"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:text>&lt;/</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>&gt;</xsl:text>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <xsl:template match="prop" mode="ast"/>

</xsl:stylesheet>
