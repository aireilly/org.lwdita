<?xml version="1.0" encoding="UTF-8"?>
<!--
  AST to Markdown DITA text.

  Overrides the parts of ast2markdown.xsl whose output the Markdown DITA parser
  misreads: source text that looks like Markdown syntax, code containing
  backticks or pipes, emphasis with edge whitespace, HTML tables that swallow
  the block after them, and YAML values that are not valid YAML.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ast="com.elovirta.dita.markdown"
                exclude-result-prefixes="xs ast"
                version="2.0">

  <xsl:function name="ast:repeat" as="xs:string">
    <xsl:param name="char" as="xs:string"/>
    <xsl:param name="count" as="xs:integer"/>
    <xsl:sequence select="string-join(for $i in 1 to $count return $char, '')"/>
  </xsl:function>

  <!-- Length of the longest run of $char in $text. -->
  <xsl:function name="ast:longest-run" as="xs:integer">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="char" as="xs:string"/>
    <xsl:sequence select="max((0, for $run in tokenize($text, concat('[^', $char, ']+'))[. ne ''] return string-length($run)))"/>
  </xsl:function>

  <!-- Characters that end a link destination early. -->
  <xsl:function name="ast:href" as="xs:string">
    <xsl:param name="href" as="xs:string?"/>
    <xsl:sequence select="replace(replace(replace(replace(replace(string($href), ' ', '%20'), '\(', '%28'), '\)', '%29'), '&lt;', '%3C'), '&gt;', '%3E')"/>
  </xsl:function>

  <!-- A line of inline content that would open a block if left alone:
       list item, thematic break, setext underline, definition, admonition. -->
  <xsl:function name="ast:guard-line" as="xs:string">
    <xsl:param name="line" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="matches($line, '^\s*[-+](\s|$)')">
        <xsl:sequence select="replace($line, '^(\s*)([-+])', '$1\\$2')"/>
      </xsl:when>
      <xsl:when test="matches($line, '^\s*\d+[.)](\s|$)')">
        <xsl:sequence select="replace($line, '^(\s*\d+)([.)])', '$1\\$2')"/>
      </xsl:when>
      <xsl:when test="matches($line, '^\s*[-=][-=\s]*$')">
        <xsl:sequence select="replace($line, '^(\s*)([-=])', '$1\\$2')"/>
      </xsl:when>
      <xsl:when test="matches($line, '^\s*:(\s|$)')">
        <xsl:sequence select="replace($line, '^(\s*):', '$1\\:')"/>
      </xsl:when>
      <xsl:when test="matches($line, '^\s*!!!')">
        <xsl:sequence select="replace($line, '^(\s*)!', '$1\\!')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$line"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template name="process-inline-contents">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:param name="prefix" tunnel="yes" as="xs:string?" select="()"/>
    <xsl:variable name="contents" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates mode="ast"/>
      </xsl:value-of>
    </xsl:variable>
    <!-- A pipe-table cell is one line. A cell of an HTML table holds blocks, which keep their indent. -->
    <xsl:variable name="idnt" as="xs:string?"
                  select="if (ancestor-or-self::tablecell and not(ast:is-block-table(ancestor::table[1]))) then () else $indent"/>
    <xsl:for-each select="tokenize($contents, '\n')">
      <xsl:value-of select="$idnt"/>
      <xsl:value-of select="$prefix"/>
      <xsl:value-of select="ast:guard-line(.)"/>
      <xsl:if test="position() ne last()">
        <xsl:value-of select="$linefeed"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- Text -->

  <xsl:template match="text()" mode="ast">
    <xsl:analyze-string select="." regex="[*_\\`{{}}\[\]()#|~^+]">
      <xsl:matching-substring>
        <xsl:text>\</xsl:text>
        <xsl:value-of select="."/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="replace(replace(replace(., '&amp;', '&amp;amp;'), '&gt;', '&amp;gt;'), '&lt;', '&amp;lt;')"/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>

  <!-- Emphasis: delimiters must touch the text, and an empty run has no form. -->

  <xsl:template name="lossless-emphasis">
    <xsl:param name="plain" as="xs:string"/>
    <xsl:param name="alternate" as="xs:string"/>
    <xsl:param name="escape" as="xs:string?" tunnel="yes"/>
    <xsl:variable name="char" as="xs:string" select="if (contains($escape, '*')) then $alternate else $plain"/>
    <xsl:variable name="inner" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates mode="ast">
          <xsl:with-param name="escape" select="concat($char, $escape)" as="xs:string?" tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="not(normalize-space($inner))">
        <xsl:value-of select="$inner"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="if (matches($inner, '^\s')) then replace($inner, '^(\s+).*$', '$1', 's') else ''"/>
        <xsl:value-of select="$char"/>
        <xsl:value-of select="replace($inner, '^\s+|\s+$', '')"/>
        <xsl:value-of select="$char"/>
        <xsl:value-of select="if (matches($inner, '\s$')) then replace($inner, '^.*?(\s+)$', '$1', 's') else ''"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="strong | cite" mode="ast">
    <xsl:call-template name="lossless-emphasis">
      <xsl:with-param name="plain" select="'**'"/>
      <xsl:with-param name="alternate" select="'__'"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="emph" mode="ast">
    <xsl:call-template name="lossless-emphasis">
      <xsl:with-param name="plain" select="'*'"/>
      <xsl:with-param name="alternate" select="'_'"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Attribute blocks: "{#id .class}" after a paragraph, on a line of its
       own, or right after an inline element. -->

  <xsl:function name="ast:attribute-block" as="xs:string">
    <xsl:param name="node" as="element()"/>
    <xsl:sequence select="concat('{', string-join((for $id in $node/@md-id return concat('#', $id),
                                                   for $c in tokenize($node/@md-class, '\s+')[. ne ''] return concat('.', $c)), ' '), '}')"/>
  </xsl:function>

  <!-- The lead of a line that continues a block. The first block of a list
       item or definition is written with no indent, after the marker, but
       its later lines need the indent of the item content, or the parser
       does not read them as part of the item. -->
  <xsl:function name="ast:continuation-lead" as="xs:string">
    <xsl:param name="node" as="element()"/>
    <xsl:param name="indent" as="xs:string"/>
    <xsl:param name="prefix" as="xs:string?"/>
    <xsl:variable name="admonition" select="$node/ancestor::admonition[1]"/>
    <xsl:sequence select="if (empty($node/preceding-sibling::*) and ($node/parent::li or $node/parent::dd))
                          then concat($prefix, ast:repeat($default-indent,
                                 count($node/ancestor::*[self::li or self::dd]
                                                        [empty($admonition) or ancestor::admonition[1] is $admonition])))
                          else concat($indent, $prefix)"/>
  </xsl:function>

  <xsl:template match="para[@md-id or @md-class]" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:param name="prefix" tunnel="yes" as="xs:string?" select="()"/>
    <xsl:call-template name="process-inline-contents"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="concat(ast:continuation-lead(., $indent, $prefix), ast:attribute-block(.))"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <!-- The block goes before whitespace that the emphasis left outside its delimiters. -->
  <xsl:template match="strong[@md-id or @md-class] | emph[@md-id or @md-class] | code[@md-id or @md-class]" mode="ast" priority="10">
    <xsl:variable name="markdown" as="xs:string">
      <xsl:value-of>
        <xsl:next-match/>
      </xsl:value-of>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="normalize-space($markdown)">
        <xsl:variable name="trailing" select="if (matches($markdown, '\s$')) then replace($markdown, '^.*?(\s+)$', '$1', 's') else ''"/>
        <xsl:value-of select="substring($markdown, 1, string-length($markdown) - string-length($trailing))"/>
        <xsl:value-of select="ast:attribute-block(.)"/>
        <xsl:value-of select="$trailing"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$markdown"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Admonitions. The syntax comes from a style: a template in the
       lossless-admonition mode that matches the value of this parameter.
       admonition-mkdocs.xsl is the built-in one and describes the contract. -->
  <xsl:param name="markdown.admonition.style" select="'mkdocs'"/>

  <!-- Puts the prefix before every line that has content, and $blank in
       place of every line that has none. -->
  <xsl:function name="ast:prefix-lines" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="prefix" as="xs:string"/>
    <xsl:param name="blank" as="xs:string"/>
    <xsl:sequence select="string-join(for $line in tokenize($text, '\n')
                                      return if (normalize-space($line)) then concat($prefix, $line) else $blank, '&#xA;')"/>
  </xsl:function>

  <xsl:function name="ast:prefix-lines" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="prefix" as="xs:string"/>
    <xsl:sequence select="ast:prefix-lines($text, $prefix, '')"/>
  </xsl:function>

  <xsl:template match="admonition" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:variable name="body" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="*" mode="ast">
          <xsl:with-param name="indent" tunnel="yes" select="''"/>
          <xsl:with-param name="prefix" tunnel="yes" select="()"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:variable name="text" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="." mode="lossless-admonition">
          <xsl:with-param name="body" select="replace($body, '\s+$', '')"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:for-each select="tokenize(replace($text, '\s+$', ''), '\n')">
      <xsl:if test=". ne ''">
        <xsl:value-of select="$indent"/>
        <xsl:value-of select="."/>
      </xsl:if>
      <xsl:value-of select="$linefeed"/>
    </xsl:for-each>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <!-- No style of that name: stop, so that notes are not written in a
       syntax nobody chose. -->
  <xsl:template match="admonition" mode="lossless-admonition">
    <xsl:message terminate="yes">[markdown] No admonition style named "<xsl:value-of select="$markdown.admonition.style"/>". The built-in style is "mkdocs". A plug-in adds a style through the dita.xsl.markdown.admonition extension point.</xsl:message>
  </xsl:template>

  <!-- An admonition that opens a list item goes on the line after the
       marker. On the marker line, Python-Markdown reads its content as a
       code block. -->
  <xsl:template match="li[*[1][self::admonition]]" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:value-of select="$indent"/>
    <xsl:variable name="label" select="if (parent::bulletlist) then '-' else concat(count(preceding-sibling::li) + 1, '.')"/>
    <xsl:value-of select="$label"/>
    <!-- Python-Markdown takes a marker for a list item only with a space after it. -->
    <xsl:value-of select="substring($default-indent, string-length($label) + 1)"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:apply-templates select="*" mode="ast">
      <xsl:with-param name="indent" tunnel="yes" select="concat($indent, $default-indent)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="admonition/text()[not(normalize-space())]" mode="ast-clean" priority="30"/>

  <xsl:template match="strikeout" mode="ast">
    <xsl:call-template name="lossless-emphasis">
      <xsl:with-param name="plain" select="'~~'"/>
      <xsl:with-param name="alternate" select="'~~'"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Inline HTML for markup Markdown has no syntax for. -->
  <xsl:template match="superscript | subscript | htmlinline" mode="ast">
    <xsl:variable name="name" select="if (self::superscript) then 'sup' else if (self::subscript) then 'sub' else string(@name)"/>
    <xsl:variable name="inner" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates mode="ast"/>
      </xsl:value-of>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="normalize-space($inner)">
        <xsl:value-of select="concat('&lt;', $name, '&gt;', $inner, '&lt;/', $name, '&gt;')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$inner"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- A definition without content still needs its line, or the next term joins it. -->
  <xsl:template match="dd[empty(node())]" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:value-of select="$indent"/>
    <xsl:text>:   &#xA0;</xsl:text>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <!-- A definition that opens with a nested definition list: the nested
       term cannot share the line of the outer marker. -->
  <xsl:template match="dd[*[1][self::definitionlist]]" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:value-of select="$indent"/>
    <xsl:text>:   &#xA0;</xsl:text>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:apply-templates select="*" mode="ast">
      <xsl:with-param name="indent" tunnel="yes" select="concat($indent, $default-indent)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Code -->

  <xsl:template name="lossless-code-span">
    <xsl:param name="raw" as="xs:string"/>
    <xsl:variable name="text" select="replace($raw, '\s+', ' ')"/>
    <xsl:choose>
      <xsl:when test="$text = ''"/>
      <xsl:when test="$text = ' '">
        <xsl:text> </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="fence" select="ast:repeat('`', ast:longest-run($text, '`') + 1)"/>
        <xsl:variable name="pad" select="if (starts-with($text, '`') or ends-with($text, '`') or
                                             (starts-with($text, ' ') and ends-with($text, ' '))) then ' ' else ''"/>
        <xsl:value-of select="$fence"/>
        <xsl:value-of select="$pad"/>
        <!-- A pipe ends a table cell even inside a code span. -->
        <xsl:value-of select="if (ancestor-or-self::tablecell) then replace($text, '\|', '\\|') else $text"/>
        <xsl:value-of select="$pad"/>
        <xsl:value-of select="$fence"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- A code span holds text only. Nested emphasis is dropped, not written
       as literal asterisks; nested links keep their destination. -->
  <xsl:template match="code" mode="ast">
    <xsl:choose>
      <xsl:when test="descendant::link[@href]">
        <xsl:apply-templates mode="lossless-code"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="lossless-code-span">
          <xsl:with-param name="raw" select="string(.)"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="text()" mode="lossless-code">
    <xsl:call-template name="lossless-code-span">
      <xsl:with-param name="raw" select="string(.)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*" mode="lossless-code">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <xsl:template match="link[@href]" mode="lossless-code">
    <xsl:text>[</xsl:text>
    <xsl:call-template name="lossless-code-span">
      <xsl:with-param name="raw" select="string(.)"/>
    </xsl:call-template>
    <xsl:text>](</xsl:text>
    <xsl:value-of select="ast:href(@href)"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="codeblock" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:param name="prefix" tunnel="yes" as="xs:string?" select="()"/>
    <xsl:variable name="classes" select="tokenize(normalize-space(@class), '\s+')" as="xs:string*"/>
    <xsl:variable name="raw" select="replace(string(.), '\r?\n$', '')" as="xs:string"/>
    <!-- Longer than any run of backticks in the content, so the content cannot close it. -->
    <xsl:variable name="fence" select="ast:repeat('`', max((3, ast:longest-run($raw, '`') + 1)))"/>
    <xsl:variable name="lead" select="concat($indent, $prefix)"/>
    <xsl:variable name="language" as="xs:string?">
      <xsl:choose>
        <xsl:when test="exists($codeblock-languge-prefix) and string-length($codeblock-languge-prefix) ne 0 and
                        count($classes) eq 1 and starts-with($classes, $codeblock-languge-prefix)">
          <xsl:sequence select="substring-after($classes, $codeblock-languge-prefix)"/>
        </xsl:when>
        <xsl:when test="count($classes) eq 1">
          <xsl:sequence select="$classes"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="$lead"/>
    <xsl:value-of select="$fence"/>
    <xsl:value-of select="replace($language, '[`\s]', '')"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:for-each select="tokenize($raw, '\r?\n')">
      <xsl:value-of select="$lead"/>
      <xsl:value-of select="."/>
      <xsl:value-of select="$linefeed"/>
    </xsl:for-each>
    <xsl:value-of select="$lead"/>
    <xsl:value-of select="$fence"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
    <!-- A code block cannot hold a link. Destinations inside it are listed after it. -->
    <xsl:if test="descendant::link[@href]">
      <xsl:value-of select="$lead"/>
      <xsl:for-each select="descendant::link[@href]">
        <xsl:if test="position() gt 1"><xsl:text> </xsl:text></xsl:if>
        <xsl:apply-templates select="." mode="ast"/>
      </xsl:for-each>
      <xsl:value-of select="$linefeed"/>
      <xsl:value-of select="$linefeed"/>
    </xsl:if>
  </xsl:template>

  <!-- Links and images -->

  <xsl:template match="link[@href]" mode="ast">
    <xsl:variable name="text" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates mode="ast"/>
      </xsl:value-of>
    </xsl:variable>
    <xsl:text>[</xsl:text>
    <xsl:choose>
      <xsl:when test="normalize-space($text)">
        <xsl:value-of select="$text"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="replace(@href, '([\\\[\]*_`])', '\\$1')"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>](</xsl:text>
    <xsl:value-of select="ast:href(@href)"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <!-- A key that did not resolve stays a key reference: "[text][key]", or "[key]" without text. -->
  <xsl:template match="link[empty(@href) and @keyref]" mode="ast">
    <xsl:variable name="text" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates mode="ast"/>
      </xsl:value-of>
    </xsl:variable>
    <xsl:if test="normalize-space($text)">
      <xsl:text>[</xsl:text>
      <xsl:value-of select="$text"/>
      <xsl:text>]</xsl:text>
    </xsl:if>
    <xsl:text>[</xsl:text>
    <xsl:value-of select="@keyref"/>
    <xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="image" mode="ast">
    <xsl:text>![</xsl:text>
    <xsl:value-of select="replace(normalize-space(@alt), '([\\\[\]])', '\\$1')"/>
    <xsl:text>](</xsl:text>
    <xsl:value-of select="ast:href(@href)"/>
    <xsl:if test="normalize-space(@title)">
      <xsl:text> "</xsl:text>
      <xsl:value-of select="replace(normalize-space(@title), '([\\&quot;])', '\\$1')"/>
      <xsl:text>"</xsl:text>
    </xsl:if>
    <xsl:text>)</xsl:text>
    <xsl:apply-templates mode="ast"/>
    <xsl:if test="@placement = 'break'">
      <xsl:value-of select="$linefeed"/>
      <xsl:value-of select="$linefeed"/>
    </xsl:if>
  </xsl:template>

  <!-- Footnote labels: one token, the same at the reference and the definition. -->
  <xsl:template match="footnote" mode="ast">
    <xsl:text>[^</xsl:text>
    <xsl:value-of select="replace(replace(normalize-space(.), '[^\p{L}\p{N}_\-]+', '-'), '^-+|-+$', '')"/>
    <xsl:text>]</xsl:text>
  </xsl:template>

  <!-- Lists -->

  <xsl:template match="bulletlist | orderedlist" mode="ast">
    <xsl:variable name="nested" select="ancestor::bulletlist or ancestor::orderedlist"/>
    <xsl:apply-templates select="li" mode="ast"/>
    <xsl:if test="@class = ('choices')">
      <!-- After a blank line, or the reader takes the line as part of the last item. -->
      <xsl:value-of select="$linefeed"/>
      <xsl:call-template name="lossless-block-class"/>
    </xsl:if>
    <!-- Without the blank line the block after a nested list joins its last item. -->
    <xsl:if test="not($nested) or following-sibling::*">
      <xsl:value-of select="$linefeed"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="li[empty(*) and not(normalize-space())]" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:value-of select="$indent"/>
    <xsl:value-of select="if (parent::bulletlist) then '-' else concat(count(preceding-sibling::li) + 1, '.')"/>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <!-- Tables -->

  <xsl:function name="ast:is-block-table" as="xs:boolean">
    <xsl:param name="table" as="element(table)"/>
    <xsl:sequence select="exists($table/*/tr/tablecell/(para | plain | codeblock | rawblock | blockquote | orderedlist |
                                                         bulletlist | definitionlist | header | table | child::div))"/>
  </xsl:function>

  <xsl:template name="lossless-pipe-row">
    <xsl:param name="cells" as="element(tablecell)*"/>
    <xsl:param name="width" as="xs:integer"/>
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:value-of select="$indent"/>
    <xsl:text>|</xsl:text>
    <xsl:for-each select="$cells">
      <xsl:variable name="cell" as="xs:string">
        <xsl:value-of>
          <xsl:call-template name="process-tablecell-contents"/>
        </xsl:value-of>
      </xsl:variable>
      <xsl:variable name="line" select="normalize-space(replace($cell, '\s*\n\s*', ' '))"/>
      <xsl:value-of select="if ($line) then concat(' ', $line, ' ') else ' '"/>
      <xsl:text>|</xsl:text>
    </xsl:for-each>
    <!-- The reader discards cells beyond the header and does not add missing
         ones, so every row is written to the same width. -->
    <xsl:for-each select="count($cells) + 1 to $width">
      <xsl:text> |</xsl:text>
    </xsl:for-each>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <xsl:template match="table" mode="ast" priority="20">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:choose>
      <xsl:when test="empty(*/tr)"/>
      <xsl:when test="ast:is-block-table(.)">
        <xsl:variable name="html" as="xs:string">
          <xsl:value-of>
            <xsl:apply-templates select="." mode="ast-html">
              <xsl:with-param name="row-prefix" tunnel="yes" select="$indent"/>
            </xsl:apply-templates>
          </xsl:value-of>
        </xsl:variable>
        <xsl:value-of select="$indent"/>
        <xsl:value-of select="$html"/>
        <xsl:value-of select="$linefeed"/>
        <xsl:value-of select="$linefeed"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="width" as="xs:integer" select="max(for $r in */tr return count($r/tablecell))"/>
        <!-- A pipe table needs a header row. Without one in the source it is left empty. -->
        <xsl:call-template name="lossless-pipe-row">
          <xsl:with-param name="cells" select="thead/tr[1]/tablecell"/>
          <xsl:with-param name="width" select="$width"/>
        </xsl:call-template>
        <xsl:value-of select="$indent"/>
        <xsl:text>|</xsl:text>
        <xsl:for-each select="1 to $width">
          <xsl:text>---|</xsl:text>
        </xsl:for-each>
        <xsl:value-of select="$linefeed"/>
        <xsl:for-each select="thead/tr[position() gt 1] | tbody/tr">
          <xsl:call-template name="lossless-pipe-row">
            <xsl:with-param name="cells" select="tablecell"/>
            <xsl:with-param name="width" select="$width"/>
          </xsl:call-template>
        </xsl:for-each>
        <xsl:call-template name="lossless-block-class"/>
        <xsl:value-of select="$linefeed"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Attribute line after a list or table, as in "{.choices}". -->
  <xsl:template name="lossless-block-class">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:variable name="classes" select="tokenize(normalize-space(@class), '\s+')[. ne '']"/>
    <xsl:if test="exists($classes)">
      <xsl:value-of select="$indent"/>
      <xsl:value-of select="concat('{', string-join(for $c in $classes return concat('.', $c), ' '), '}')"/>
      <xsl:value-of select="$linefeed"/>
    </xsl:if>
  </xsl:template>

  <!-- ============================================================== -->
  <!-- Tables with blocks in cells, as one HTML block                 -->
  <!-- ============================================================== -->

  <!-- A pipe-table cell holds one line. A table with a list, code or several
       paragraphs in a cell is written as HTML. The reader builds a DITA
       table from HTML only when the whole table is one HTML block, and a
       blank line ends an HTML block, so the cell content is HTML too and
       line breaks inside code are character references. -->

  <xsl:function name="ast:html-text" as="xs:string">
    <xsl:param name="text" as="xs:string?"/>
    <xsl:sequence select="replace(replace(replace(string($text), '&amp;', '&amp;amp;'), '&lt;', '&amp;lt;'), '&gt;', '&amp;gt;')"/>
  </xsl:function>

  <xsl:function name="ast:html-attr" as="xs:string">
    <xsl:param name="text" as="xs:string?"/>
    <xsl:sequence select="replace(ast:html-text(normalize-space($text)), '&quot;', '&amp;quot;')"/>
  </xsl:function>

  <xsl:template name="lossless-html-element">
    <xsl:param name="name" as="xs:string"/>
    <xsl:param name="attributes" as="xs:string" select="''"/>
    <xsl:value-of select="concat('&lt;', $name, $attributes, '&gt;')"/>
    <xsl:apply-templates mode="ast-html"/>
    <xsl:value-of select="concat('&lt;/', $name, '&gt;')"/>
  </xsl:template>

  <xsl:template match="text()" mode="ast-html">
    <xsl:value-of select="ast:html-text(.)"/>
  </xsl:template>

  <xsl:template match="*" mode="ast-html" priority="-5">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <xsl:template match="para | plain" mode="ast-html">
    <xsl:call-template name="lossless-html-element"><xsl:with-param name="name" select="'p'"/></xsl:call-template>
  </xsl:template>

  <xsl:template match="header" mode="ast-html">
    <xsl:text>&lt;p&gt;&lt;b&gt;</xsl:text>
    <xsl:apply-templates mode="#current"/>
    <xsl:text>&lt;/b&gt;&lt;/p&gt;</xsl:text>
  </xsl:template>

  <xsl:template match="bulletlist | orderedlist | li | blockquote | definitionlist | dt | dd |
                       strong | emph | superscript | subscript | htmlinline | strikeout | cite" mode="ast-html">
    <xsl:call-template name="lossless-html-element">
      <xsl:with-param name="name"
                      select="if (self::bulletlist) then 'ul' else if (self::orderedlist) then 'ol'
                              else if (self::definitionlist) then 'dl'
                              else if (self::strong or self::cite) then 'b' else if (self::emph) then 'i'
                              else if (self::superscript) then 'sup' else if (self::subscript) then 'sub'
                              else if (self::strikeout) then 's' else if (self::htmlinline) then string(@name)
                              else name()"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="code" mode="ast-html">
    <xsl:value-of select="concat('&lt;code&gt;', ast:html-text(replace(string(.), '\s+', ' ')), '&lt;/code&gt;')"/>
  </xsl:template>

  <xsl:template match="codeblock" mode="ast-html">
    <xsl:variable name="classes" select="tokenize(normalize-space(@class), '\s+')[. ne '']"/>
    <xsl:text>&lt;pre&gt;&lt;code</xsl:text>
    <xsl:if test="count($classes) eq 1">
      <xsl:value-of select="concat(' class=&quot;', ast:html-attr(if (starts-with($classes, 'language-')) then $classes else concat('language-', $classes)), '&quot;')"/>
    </xsl:if>
    <xsl:text>&gt;</xsl:text>
    <xsl:value-of select="replace(replace(ast:html-text(replace(string(.), '\r?\n$', '')), '\r?\n', '&amp;#10;'), '^ | $|  ', '&amp;#32;&amp;#32;')"/>
    <xsl:text>&lt;/code&gt;&lt;/pre&gt;</xsl:text>
  </xsl:template>

  <xsl:template match="admonition" mode="ast-html">
    <xsl:call-template name="lossless-html-element">
      <xsl:with-param name="name" select="'div'"/>
      <xsl:with-param name="attributes" select="concat(' data-class=&quot;note&quot; data-type=&quot;', ast:html-attr(@type), '&quot;')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="link[@href]" mode="ast-html">
    <xsl:variable name="text" as="xs:string">
      <xsl:value-of><xsl:apply-templates mode="#current"/></xsl:value-of>
    </xsl:variable>
    <xsl:value-of select="concat('&lt;a href=&quot;', ast:html-attr(ast:href(@href)), '&quot;&gt;',
                                 if (normalize-space($text)) then $text else ast:html-text(@href), '&lt;/a&gt;')"/>
  </xsl:template>

  <xsl:template match="image" mode="ast-html">
    <xsl:value-of select="concat('&lt;img src=&quot;', ast:html-attr(ast:href(@href)), '&quot; alt=&quot;', ast:html-attr(@alt), '&quot;',
                                 if (normalize-space(@title)) then concat(' title=&quot;', ast:html-attr(@title), '&quot;') else '', '/&gt;')"/>
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <xsl:template match="linebreak" mode="ast-html">&lt;br/&gt;</xsl:template>

  <!-- Markdown footnote syntax is not parsed inside an HTML block. The note
       text goes in place, in parentheses. -->
  <xsl:template match="footnote" mode="ast-html">
    <xsl:variable name="label" select="string(.)"/>
    <xsl:text> (</xsl:text>
    <xsl:apply-templates select="(ancestor::pandoc/footnoteblock[string(footnote) = $label])[1]/(node() except footnote)" mode="#current"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="table" mode="ast-html">
    <xsl:param name="row-prefix" as="xs:string" tunnel="yes" select="''"/>
    <xsl:variable name="classes" select="tokenize(normalize-space(@class), '\s+')[. ne '']"/>
    <xsl:text>&lt;table</xsl:text>
    <xsl:if test="exists($classes)">
      <xsl:value-of select="concat(' class=&quot;', ast:html-attr(string-join($classes, ' ')), '&quot;')"/>
    </xsl:if>
    <xsl:text>&gt;</xsl:text>
    <xsl:for-each select="thead | tbody">
      <xsl:variable name="cell" select="if (self::thead) then 'th' else 'td'"/>
      <xsl:value-of select="concat('&#xA;', $row-prefix, '&lt;', name(), '&gt;')"/>
      <xsl:for-each select="tr">
        <xsl:value-of select="concat('&#xA;', $row-prefix, '&lt;tr&gt;')"/>
        <xsl:for-each select="tablecell">
          <xsl:value-of select="concat('&lt;', $cell)"/>
          <xsl:for-each select="@colspan | @rowspan | @align">
            <xsl:value-of select="concat(' ', name(), '=&quot;', ast:html-attr(.), '&quot;')"/>
          </xsl:for-each>
          <xsl:text>&gt;</xsl:text>
          <xsl:apply-templates mode="ast-html"/>
          <xsl:value-of select="concat('&lt;/', $cell, '&gt;')"/>
        </xsl:for-each>
        <xsl:text>&lt;/tr&gt;</xsl:text>
      </xsl:for-each>
      <xsl:value-of select="concat('&#xA;', $row-prefix, '&lt;/', name(), '&gt;')"/>
    </xsl:for-each>
    <xsl:value-of select="concat('&#xA;', $row-prefix, '&lt;/table&gt;')"/>
  </xsl:template>

  <!-- YAML -->

  <xsl:function name="ast:yaml-scalar" as="xs:string">
    <xsl:param name="value" as="xs:string"/>
    <xsl:variable name="v" select="normalize-space($value)"/>
    <xsl:choose>
      <xsl:when test="matches($v, '^[\p{L}\p{N}][^:#]*$') and not(matches($v, '\s$')) and
                      not(lower-case($v) = ('true', 'false', 'null', 'yes', 'no', 'on', 'off'))">
        <xsl:sequence select="$v"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="concat('&quot;', replace(replace($v, '\\', '\\\\'), '&quot;', '\\&quot;'), '&quot;')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template match="head/map" mode="ast">
    <xsl:for-each select="entry">
      <xsl:value-of select="@key"/>
      <xsl:text>:</xsl:text>
      <xsl:choose>
        <xsl:when test="array">
          <xsl:value-of select="$linefeed"/>
          <xsl:for-each select="array/entry">
            <xsl:text>  - </xsl:text>
            <xsl:value-of select="ast:yaml-scalar(string(.))"/>
            <xsl:value-of select="$linefeed"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text> </xsl:text>
          <xsl:value-of select="ast:yaml-scalar(string(.))"/>
          <xsl:value-of select="$linefeed"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- Raw DITA, written as it is. Every line of a block gets the indent
       and prefix of its container, or the block ends there. -->
  <xsl:template match="rawblock" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:param name="prefix" tunnel="yes" as="xs:string?" select="()"/>
    <xsl:variable name="lead" select="ast:continuation-lead(., $indent, $prefix)" as="xs:string"/>
    <xsl:for-each select="tokenize(string(.), '\n')">
      <xsl:value-of select="concat(if (position() eq 1) then concat($indent, $prefix) else $lead, .)"/>
      <xsl:value-of select="$linefeed"/>
    </xsl:for-each>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <xsl:template match="rawinline" mode="ast">
    <xsl:value-of select="string(.)"/>
  </xsl:template>

  <!-- In an HTML table, raw DITA is markup already. -->
  <xsl:template match="rawblock | rawinline" mode="ast-html">
    <xsl:value-of select="string(.)"/>
  </xsl:template>

  <xsl:template match="rawblock//text() | rawinline//text()" mode="ast-clean" priority="30">
    <xsl:value-of select="."/>
  </xsl:template>

</xsl:stylesheet>
