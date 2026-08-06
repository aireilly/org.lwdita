<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:x="com.elovirta.dita.markdown.rawdita"
                exclude-result-prefixes="xs x"
                version="2.0">

  <!-- Elements without a lossless Markdown mapping are serialized as raw
       DITA markup inside a <rawnode> AST element.  The rawnode passes
       through flatten / ast-clean untouched and is emitted verbatim in
       the ast -> text phase (template in ast2markdown.xsl). -->

  <!-- === Attribute-triggered raw passthrough ===
       Any element carrying @conref, @conkeyref, @keyref, @id, or
       @outputclass is kept as raw DITA so the attribute survives
       roundtripping.  Structural containers whose IDs/classes already
       map to Markdown header {#id .class} syntax are excluded.
       Block-level elements emit <rawblock>; inline elements emit
       <rawnode>. -->

  <xsl:function name="x:is-dita-block" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="contains($e/@class,' topic/p ') or
                          contains($e/@class,' topic/note ') or
                          contains($e/@class,' topic/table ') or
                          contains($e/@class,' topic/ul ') or
                          contains($e/@class,' topic/ol ') or
                          contains($e/@class,' topic/dl ') or
                          contains($e/@class,' topic/lq ') or
                          contains($e/@class,' topic/fig ') or
                          contains($e/@class,' topic/pre ') or
                          contains($e/@class,' topic/div ') or
                          contains($e/@class,' topic/bodydiv ') or
                          contains($e/@class,' topic/sectiondiv ') or
                          contains($e/@class,' topic/lines ')"/>
  </xsl:function>

  <xsl:template match="*[@conref or @conkeyref]
                        [not(contains(@class,' topic/topic '))]"
                priority="112">
    <xsl:choose>
      <xsl:when test="x:is-dita-block(.)">
        <rawblock><xsl:value-of select="x:serialize(.)"/></rawblock>
      </xsl:when>
      <xsl:otherwise>
        <rawnode><xsl:value-of select="x:serialize(.)"/></rawnode>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*[@keyref]
                        [not(contains(@class,' topic/topic '))]"
                priority="111">
    <xsl:choose>
      <xsl:when test="x:is-dita-block(.)">
        <rawblock><xsl:value-of select="x:serialize(.)"/></rawblock>
      </xsl:when>
      <xsl:otherwise>
        <rawnode><xsl:value-of select="x:serialize(.)"/></rawnode>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*[@id or @outputclass]
                        [not(contains(@class,' topic/topic '))]
                        [not(contains(@class,' topic/body '))]
                        [not(contains(@class,' topic/title '))]
                        [not(contains(@class,' topic/section '))]
                        [not(contains(@class,' topic/example '))]
                        [not(contains(@class,' topic/pre '))]
                        [not(contains(@class,' topic/prolog '))]
                        [not(contains(@class,' topic/abstract '))]
                        [not(contains(@class,' topic/related-links '))]"
                priority="110">
    <xsl:choose>
      <xsl:when test="x:is-dita-block(.)">
        <rawblock><xsl:value-of select="x:serialize(.)"/></rawblock>
      </xsl:when>
      <xsl:otherwise>
        <rawnode><xsl:value-of select="x:serialize(.)"/></rawnode>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Container escalation: when a list item, table entry, or
       definition list child carries a raw-triggering attribute,
       serialize the entire container as raw DITA. -->
  <xsl:template match="*[contains(@class,' topic/ul ') or contains(@class,' topic/ol ')]
                        [*[contains(@class,' topic/li ')]
                          [@id or @outputclass or @conref or @conkeyref or @keyref]]"
                priority="115">
    <rawblock><xsl:value-of select="x:serialize(.)"/></rawblock>
  </xsl:template>

  <xsl:template match="*[contains(@class,' topic/dl ')]
                        [.//*[contains(@class,' topic/dlentry ') or
                              contains(@class,' topic/dt ') or
                              contains(@class,' topic/dd ')]
                             [@id or @outputclass or @conref or @conkeyref or @keyref]]"
                priority="115">
    <rawblock><xsl:value-of select="x:serialize(.)"/></rawblock>
  </xsl:template>

  <xsl:template match="*[contains(@class,' topic/table ')]
                        [.//*[contains(@class,' topic/entry ') or
                              contains(@class,' topic/row ')]
                             [@id or @outputclass or @conref or @conkeyref or @keyref]]"
                priority="115">
    <rawblock><xsl:value-of select="x:serialize(.)"/></rawblock>
  </xsl:template>

  <!-- === Domain-based raw passthrough ===
       Specialized elements without clean Markdown equivalents. -->

  <xsl:template match="*[contains(@class,' ui-d/uicontrol ')] |
                       *[contains(@class,' ui-d/shortcut ')] |
                       *[contains(@class,' ui-d/menucascade ')] |
                       *[contains(@class,' ui-d/wintitle ')] |
                       *[contains(@class,' sw-d/filepath ')] |
                       *[contains(@class,' sw-d/cmdname ')] |
                       *[contains(@class,' sw-d/varname ')] |
                       *[contains(@class,' sw-d/systemoutput ')] |
                       *[contains(@class,' sw-d/userinput ')] |
                       *[contains(@class,' sw-d/msgph ')] |
                       *[contains(@class,' sw-d/msgnum ')] |
                       *[contains(@class,' topic/ph ')]
                         [not(contains(@class,' hi-d/b '))]
                         [not(contains(@class,' hi-d/i '))]
                         [not(contains(@class,' hi-d/tt '))]
                         [not(contains(@class,' pr-d/codeph '))]"
                priority="100">
    <rawnode>
      <xsl:value-of select="x:serialize(.)"/>
    </rawnode>
  </xsl:template>

  <!-- Serialize a DITA element to its XML string representation,
       stripping DITA-OT internal attributes. -->
  <xsl:function name="x:serialize" as="xs:string">
    <xsl:param name="e" as="element()"/>
    <xsl:variable name="name" select="local-name($e)"/>
    <xsl:variable name="atts" as="xs:string*">
      <xsl:for-each select="$e/@*[not(local-name() = ('class','domains','xtrf','xtrc','specializations'))]
                                 [not(starts-with(name(),'dita:'))]
                                 [not(starts-with(name(),'xmlns'))]"
                    xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/">
        <xsl:if test="not(namespace-uri() = 'http://dita.oasis-open.org/architecture/2005/')">
          <xsl:sequence select="concat(' ', name(), '=&quot;',
                                       replace(replace(replace(., '&amp;', '&amp;amp;'), '&lt;', '&amp;lt;'), '&quot;', '&amp;quot;'),
                                       '&quot;')"/>
        </xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="content" as="xs:string*">
      <xsl:for-each select="$e/node()">
        <xsl:choose>
          <xsl:when test="self::text()">
            <xsl:sequence select="replace(replace(replace(string(.), '&amp;', '&amp;amp;'), '&lt;', '&amp;lt;'), '&gt;', '&amp;gt;')"/>
          </xsl:when>
          <xsl:when test="self::*">
            <xsl:sequence select="x:serialize(.)"/>
          </xsl:when>
        </xsl:choose>
      </xsl:for-each>
    </xsl:variable>
    <xsl:sequence select="concat('&lt;', $name, string-join($atts,''), '&gt;',
                                 string-join($content,''),
                                 '&lt;/', $name, '&gt;')"/>
  </xsl:function>

</xsl:stylesheet>
