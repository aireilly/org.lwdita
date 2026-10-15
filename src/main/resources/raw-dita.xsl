<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:x="com.elovirta.dita.markdown.rawdita"
                exclude-result-prefixes="xs x"
                version="3.0">

  <!-- Raw DITA passthrough. When enabled, DITA elements that have no
       lossless Markdown mapping are written as raw DITA markup, which the
       Markdown reader parses back when its raw-dita feature is on.

       Inline elements emit their start and end tags as <rawinline> AST
       nodes and process their children normally, so text between the tags
       still gets Markdown escaping. Block elements are serialized whole
       into a <rawblock>, because Markdown is not parsed inside an HTML
       block.

       Only allowlisted elements are written raw. The reader parses raw
       markup with an HTML5 parser, so an element is left to the normal
       templates when its raw form would be restructured by that parser:
       tables, images, and paragraphs that contain lists are examples. -->

  <xsl:param name="raw-dita" as="xs:string" select="'no'"/>

  <xsl:variable name="x:enabled" as="xs:boolean" select="$raw-dita = ('yes', 'true')"/>

  <xsl:function name="x:is" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:param name="classes" as="xs:string+"/>
    <xsl:sequence select="some $c in $classes satisfies contains($e/@class, concat(' ', $c, ' '))"/>
  </xsl:function>

  <xsl:function name="x:is-raw-block" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="x:is($e, ('topic/p', 'topic/note', 'topic/lq', 'topic/fig', 'topic/div', 'topic/bodydiv',
                                    'topic/sectiondiv', 'topic/lines', 'topic/ul', 'topic/ol', 'topic/sl',
                                    'topic/simpletable'))"/>
  </xsl:function>

  <!-- Phrases that may be written raw when an attribute needs preserving.
       xref, image and fn are left out because their normal output rewrites
       or moves content. -->
  <xsl:function name="x:is-raw-phrase" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="x:is($e, ('topic/ph', 'topic/keyword', 'topic/term', 'topic/cite', 'topic/q', 'topic/tm'))
                          and not(x:is($e, 'task/cmd'))"/>
  </xsl:function>

  <!-- Phrases that are always written raw: they have no Markdown
       equivalent. A code span cannot hold markup, so codeph with child
       elements is raw too. -->
  <xsl:function name="x:is-domain-phrase" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="(contains($e/@class, ' ui-d/') or
                           contains($e/@class, ' sw-d/') or
                           x:is($e, ('hi-d/sup', 'hi-d/sub', 'hi-d/u', 'hi-d/line-through', 'hi-d/overline')) or
                           (x:is($e, 'pr-d/codeph') and exists($e/*)))
                          and not(x:is($e, 'task/cmd'))"/>
  </xsl:function>

  <xsl:function name="x:has-raw-attribute" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="exists($e/(@id | @outputclass | @conref | @conkeyref | @keyref))"/>
  </xsl:function>

  <!-- A list item or simple table part cannot be written raw on its own,
       so its whole container is. -->
  <xsl:function name="x:has-raw-part" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="(x:is($e, ('topic/ul', 'topic/ol')) and
                           exists($e/*[x:is(., 'topic/li')][x:has-raw-attribute(.)])) or
                          (x:is($e, 'topic/sl') and
                           exists($e/*[x:is(., 'topic/sli')][x:has-raw-attribute(.)])) or
                          (x:is($e, 'topic/simpletable') and
                           exists($e/*[x:is(., ('topic/sthead', 'topic/strow'))]/descendant-or-self::*
                                     [x:is(., ('topic/sthead', 'topic/strow', 'topic/stentry'))]
                                     [x:has-raw-attribute(.)]))"/>
  </xsl:function>

  <!-- Contexts where raw markup cannot appear: code, syntax diagrams, and,
       for blocks, table cells. -->
  <xsl:function name="x:in-excluded-context" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="exists($e/ancestor::*[x:is(., ('topic/pre', 'pr-d/syntaxdiagram')) or
                                                (x:is(., 'pr-d/codeph') and empty(*))]) or
                          (x:is-raw-block($e) and
                           exists($e/ancestor::*[x:is(., ('topic/entry', 'topic/stentry'))]))"/>
  </xsl:function>

  <!-- HTML5 parsing and the reader's HDITA mapping change these: table
       content is moved out of <table>, image is renamed to img, area,
       param, source and track are void, title content is read as text, dl
       gets a second dlentry wrapper, and a <p> is closed by a nested list,
       paragraph or division. -->
  <xsl:function name="x:is-html-safe" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="empty($e/descendant-or-self::*[local-name() = ('table', 'image', 'area', 'param', 'source', 'track', 'dl')]) and
                          empty($e/descendant-or-self::*[local-name() = 'title'][*]) and
                          empty($e/descendant-or-self::*[local-name() = 'p']
                                  /descendant::*[local-name() = ('p', 'ul', 'ol', 'dl', 'div', 'pre', 'section', 'table', 'summary')])"/>
  </xsl:function>

  <xsl:template match="*[$x:enabled]
                        [if (x:is-raw-block(.))
                         then x:has-raw-attribute(.) or x:has-raw-part(.) or x:is(., 'topic/note')
                         else (x:is-raw-phrase(.) and x:has-raw-attribute(.)) or x:is-domain-phrase(.)]
                        [not(x:in-excluded-context(.))]
                        [x:is-html-safe(.)]"
                priority="100">
    <xsl:choose>
      <xsl:when test="x:is-raw-block(.)">
        <rawblock>
          <xsl:value-of select="x:start-tag(.)"/>
          <xsl:text>&#xA;</xsl:text>
          <xsl:value-of select="string-join(node() ! x:serialize(.), '')"/>
          <xsl:if test="exists(node())">
            <xsl:text>&#xA;</xsl:text>
          </xsl:if>
          <xsl:value-of select="x:end-tag(.)"/>
        </rawblock>
      </xsl:when>
      <xsl:otherwise>
        <rawinline><xsl:value-of select="x:start-tag(.)"/></rawinline>
        <xsl:apply-templates/>
        <rawinline><xsl:value-of select="x:end-tag(.)"/></rawinline>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Serialization -->

  <xsl:function name="x:start-tag" as="xs:string">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="concat('&lt;', name($e),
                                 string-join(x:attributes($e) ! concat(' ', name(.), '=&quot;', x:escape-attribute(.), '&quot;'), ''),
                                 '&gt;')"/>
  </xsl:function>

  <!-- Always write an end tag: the reader parses raw DITA as HTML5, which
       ignores the self-closing flag on elements that are not void. -->
  <xsl:function name="x:end-tag" as="xs:string">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="concat('&lt;/', name($e), '&gt;')"/>
  </xsl:function>

  <!-- Drop attributes that DITA-OT adds during processing. -->
  <xsl:function name="x:attributes" as="attribute()*">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence select="$e/@*[not(local-name() = ('class', 'domains', 'xtrf', 'xtrc', 'specializations'))]
                               [not(namespace-uri() = ('http://dita.oasis-open.org/architecture/2005/',
                                                       'http://dita-ot.sourceforge.net',
                                                       'http://dita-ot.sourceforge.net/ns/201007/dita-ot'))]"/>
  </xsl:function>

  <xsl:function name="x:serialize" as="xs:string">
    <xsl:param name="n" as="node()"/>
    <xsl:choose>
      <xsl:when test="$n/self::*">
        <xsl:sequence select="concat(x:start-tag($n),
                                     string-join($n/node() ! x:serialize(.), ''),
                                     x:end-tag($n))"/>
      </xsl:when>
      <xsl:when test="$n/self::text()">
        <xsl:sequence select="x:escape-text($n)"/>
      </xsl:when>
      <xsl:when test="$n/self::comment()">
        <xsl:sequence select="concat('&lt;!--', string($n), '--&gt;')"/>
      </xsl:when>
      <!-- Processing instructions are DITA-OT internals. -->
      <xsl:otherwise>
        <xsl:sequence select="''"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- A raw block ends at the first blank line, so whitespace that DITA
       treats as insignificant is collapsed or, in element-only content,
       dropped. Newlines in preformatted text are written as character
       references. -->
  <xsl:function name="x:escape-text" as="xs:string">
    <xsl:param name="t" as="text()"/>
    <xsl:variable name="escaped" select="replace(replace(replace(string($t), '&amp;', '&amp;amp;'), '&lt;', '&amp;lt;'), '&gt;', '&amp;gt;')"/>
    <xsl:choose>
      <xsl:when test="$t/ancestor::*[x:is(., 'topic/pre') or @xml:space = 'preserve']">
        <xsl:sequence select="replace($escaped, '\n', '&amp;#10;')"/>
      </xsl:when>
      <xsl:when test="not(normalize-space($t)) and
                      x:is($t/.., ('topic/ul', 'topic/ol', 'topic/sl',
                                   'topic/simpletable', 'topic/sthead', 'topic/strow', 'topic/fig', 'topic/lq'))">
        <xsl:sequence select="''"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="replace($escaped, '\s+', ' ')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="x:escape-attribute" as="xs:string">
    <xsl:param name="a" as="attribute()"/>
    <xsl:sequence select="replace(replace(replace(replace(replace(replace(string($a),
                            '&amp;', '&amp;amp;'), '&lt;', '&amp;lt;'), '&gt;', '&amp;gt;'),
                            '&quot;', '&amp;quot;'), '&#xA;', '&amp;#10;'), '&#x9;', '&amp;#9;')"/>
  </xsl:function>

</xsl:stylesheet>
