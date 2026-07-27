<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:js="js">

  <xsl:template match="component" mode="ast">
    <xsl:text>&lt;</xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:for-each select="prop">
      <xsl:text> </xsl:text>
      <xsl:value-of select="@name"/>
      <xsl:text>=</xsl:text>
      <xsl:choose>
        <xsl:when test="@value">
          <xsl:text>"</xsl:text>
          <xsl:value-of select="@value"/>
          <xsl:text>"</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>{</xsl:text>
          <xsl:apply-templates select="js:*" mode="#current"/>
          <xsl:text>}</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
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

  <xsl:template match="js:array" mode="ast">
    <xsl:text>[</xsl:text>
    <xsl:for-each select="js:*">
      <xsl:if test="position() ne 1">, </xsl:if>
      <xsl:apply-templates select="." mode="#current"/>
    </xsl:for-each>
    <xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="js:string" mode="ast">
    <xsl:text>"</xsl:text>
    <xsl:value-of select="."/>
    <xsl:text>"</xsl:text>
  </xsl:template>

  <xsl:template match="js:boolean | js:number" mode="ast">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="prop" mode="ast"/>

</xsl:stylesheet>
