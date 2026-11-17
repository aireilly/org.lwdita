<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ast="com.elovirta.dita.markdown"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                exclude-result-prefixes="xs ast dita2html">

  <!-- Append source text that did not reach the AST. 'no' turns the safety net off. -->
  <xsl:param name="markdown.heal" select="'yes'"/>
  <!-- Heading used for the appended content. -->
  <xsl:param name="markdown.heal.title" select="'Unplaced source content'"/>

  <!-- ============================================================== -->
  <!-- Pipeline                                                       -->
  <!-- ============================================================== -->

  <xsl:template match="/">
    <xsl:variable name="ast" as="element()">
      <xsl:apply-templates/>
    </xsl:variable>
    <xsl:variable name="ast-plain" as="element()">
      <xsl:apply-templates select="$ast" mode="lossless-strip"/>
    </xsl:variable>
    <xsl:variable name="ast-healed" as="element()">
      <xsl:apply-templates select="$ast-plain" mode="lossless-heal">
        <xsl:with-param name="source" select="/" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="ast-flat" as="node()">
      <xsl:apply-templates select="$ast-healed" mode="flatten"/>
    </xsl:variable>
    <xsl:variable name="ast-clean" as="node()">
      <xsl:apply-templates select="$ast-flat" mode="ast-clean"/>
    </xsl:variable>
    <xsl:variable name="ast-merged" as="node()">
      <xsl:apply-templates select="$ast-clean" mode="lossless-merge"/>
    </xsl:variable>
    <xsl:apply-templates select="$ast-merged" mode="ast"/>
  </xsl:template>

  <!-- ============================================================== -->
  <!-- Elements without a template                                    -->
  <!-- ============================================================== -->

  <!-- The base transform wraps an element it has no template for in a
       highlighted span and prints the element path around the content, as
       dita2xhtml once did for stylesheet authors. A stylesheet that imports
       the base cannot replace that rule without replacing every rule, so the
       markers are taken out of the AST here and the content stays. -->
  <xsl:template match="span[@style = 'background-color: yellow;']" mode="lossless-strip">
    <xsl:message>[markdown] No template for <xsl:value-of select="replace(normalize-space(span[1]), '^\[|\{.*$', '')"/>; content kept, markup dropped.</xsl:message>
    <xsl:apply-templates select="node() except span[@style = 'font-weight: bold']" mode="#current"/>
  </xsl:template>

  <!-- A footnote definition without a reference is not part of the document
       for a Markdown parser. It becomes an ordinary paragraph. -->
  <xsl:template match="footnoteblock[not(string(footnote) = ancestor::pandoc//footnote[empty(parent::footnoteblock)]/string())]" mode="lossless-strip">
    <para>
      <xsl:apply-templates select="node() except footnote" mode="#current"/>
    </para>
  </xsl:template>

  <xsl:template match="@* | node()" mode="lossless-strip">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <!-- ============================================================== -->
  <!-- Safety net: text in the source that is absent from the AST     -->
  <!-- ============================================================== -->

  <!-- Letters and digits only. Spacing and punctuation change on the way
       through the transform, so they take no part in the comparison. -->
  <xsl:function name="ast:squeeze" as="xs:string">
    <xsl:param name="text" as="xs:string?"/>
    <xsl:sequence select="replace(string($text), '[^\p{L}\p{N}]+', '')"/>
  </xsl:function>

  <!-- Link text and link descriptions that preprocessing copied in from the
       link target. They follow a "ditaot" instruction that says so. -->
  <xsl:function name="ast:is-generated" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="exists($node/ancestor-or-self::node()
                                   [preceding-sibling::processing-instruction('ditaot')[1] = ('gentext', 'genshortdesc')])"/>
  </xsl:function>

  <xsl:function name="ast:path" as="xs:string">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="string-join($node/ancestor::*/name(), '/')"/>
  </xsl:function>

  <xsl:template match="pandoc" mode="lossless-heal">
    <xsl:param name="source" as="document-node()" tunnel="yes"/>
    <xsl:variable name="ast" select="." as="element()"/>
    <xsl:variable name="have" as="xs:string"
                  select="ast:squeeze(string-join((.//text(), .//@*), ''))"/>
    <xsl:variable name="missing" as="text()*"
                  select="if ($markdown.heal = 'yes')
                          then $source//text()[normalize-space()]
                                 [empty(ancestor::*[contains(@class, ' ditaot-d/')])]
                                 [not(ast:is-generated(.))]
                                 [ast:squeeze(.) ne '']
                                 [not(contains($have, ast:squeeze(.)))]
                          else ()"/>
    <xsl:copy>
      <xsl:copy-of select="@* | node() except footnoteblock"/>
      <xsl:if test="exists($missing)">
        <header level="2">
          <xsl:value-of select="$markdown.heal.title"/>
        </header>
        <xsl:for-each select="$missing">
          <xsl:message>[markdown] No template placed text of <xsl:value-of select="ast:path(.)"/>; appended under "<xsl:value-of select="$markdown.heal.title"/>": <xsl:value-of select="substring(normalize-space(.), 1, 60)"/></xsl:message>
          <para>
            <code><xsl:value-of select="ast:path(.)"/></code>
            <xsl:text> </xsl:text>
            <xsl:value-of select="normalize-space(.)"/>
          </para>
        </xsl:for-each>
      </xsl:if>
      <xsl:copy-of select="footnoteblock"/>
    </xsl:copy>
  </xsl:template>

  <!-- A table cell with both loose text and blocks: the loose text becomes a
       paragraph, or it runs into the block next to it. -->
  <xsl:template match="tablecell[*[ast:is-block(.)]]" mode="flatten" priority="200">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="flatten"/>
      <xsl:for-each-group select="node()" group-adjacent="ast:is-block(.)">
        <xsl:choose>
          <xsl:when test="current-grouping-key()">
            <xsl:apply-templates select="current-group()" mode="flatten"/>
          </xsl:when>
          <xsl:when test="not(normalize-space(string-join(current-group(), '')))"/>
          <xsl:otherwise>
            <para>
              <xsl:apply-templates select="current-group()" mode="flatten"/>
            </para>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each-group>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="strong[ancestor::strong] | emph[ancestor::emph]" mode="lossless-merge" priority="5">
    <xsl:apply-templates select="node()" mode="#current"/>
  </xsl:template>

  <!-- Adjacent runs of the same emphasis are one run. "**a****b**" does not parse. -->
  <xsl:template match="@* | node()" mode="lossless-merge">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:for-each-group select="node()" group-adjacent="if (self::strong) then 1 else if (self::emph) then 2 else 0">
        <xsl:choose>
          <xsl:when test="current-grouping-key() ne 0 and count(current-group()) gt 1">
            <xsl:element name="{name(current-group()[1])}">
              <xsl:apply-templates select="current-group()/node()" mode="#current"/>
            </xsl:element>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="current-group()" mode="#current"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each-group>
    </xsl:copy>
  </xsl:template>

  <!-- ============================================================== -->
  <!-- Front matter: prolog, titlealts, index terms, data             -->
  <!-- ============================================================== -->

  <xsl:variable name="lossless.internal-atts" as="xs:string*"
                select="('class', 'xtrf', 'xtrc', 'domains', 'specializations', 'DITAArchVersion', 'xml:lang', 'translate', 'dir')"/>

  <xsl:template match="*" mode="chapterHead">
    <xsl:variable name="topics" as="element()*"
                  select="if (self::dita) then *[contains(@class, ' topic/topic ')] else ."/>
    <xsl:variable name="fields" as="element(field)*">
      <xsl:apply-templates select="$topics/*[contains(@class, ' topic/titlealts ')]/*" mode="lossless-meta"/>
      <xsl:apply-templates select="$topics/*[contains(@class, ' topic/prolog ')]/*" mode="lossless-meta"/>
      <!-- Metadata that sits in the body or in nested topics has no Markdown
           equivalent in place, so it joins the front matter. -->
      <xsl:apply-templates mode="lossless-meta"
                           select="descendant::*[contains(@class, ' topic/prolog ') or contains(@class, ' topic/titlealts ')]
                                               [empty(parent::* intersect $topics)]/*"/>
      <xsl:apply-templates mode="lossless-meta"
                           select="descendant::*[contains(@class, ' topic/indexterm ') or contains(@class, ' topic/indextermref ') or
                                                 contains(@class, ' topic/data ') or contains(@class, ' topic/data-about ')]
                                               [empty(ancestor::*[contains(@class, ' topic/prolog ') or
                                                                  contains(@class, ' topic/indexterm ') or
                                                                  contains(@class, ' topic/data ') or
                                                                  contains(@class, ' topic/data-about ')])]"/>
    </xsl:variable>
    <xsl:if test="exists($fields)">
      <head>
        <map>
          <xsl:for-each-group select="$fields[normalize-space()]" group-by="ast:yaml-key(@key)">
            <!-- Repeated values stay repeated: map metadata cascades into a
                 topic once per reference, and the verifier counts occurrences. -->
            <xsl:variable name="values" select="current-group()/normalize-space()" as="xs:string+"/>
            <entry key="{current-grouping-key()}">
              <xsl:choose>
                <xsl:when test="count($values) eq 1">
                  <xsl:value-of select="$values"/>
                </xsl:when>
                <xsl:otherwise>
                  <array>
                    <xsl:for-each select="$values">
                      <entry><xsl:value-of select="."/></entry>
                    </xsl:for-each>
                  </array>
                </xsl:otherwise>
              </xsl:choose>
            </entry>
          </xsl:for-each-group>
        </map>
      </head>
    </xsl:if>
  </xsl:template>

  <xsl:function name="ast:yaml-key" as="xs:string">
    <xsl:param name="key" as="xs:string"/>
    <xsl:variable name="clean" select="replace(replace(normalize-space($key), '[^A-Za-z0-9_.\-]+', '-'), '^-+|-+$', '')"/>
    <xsl:sequence select="if ($clean) then $clean else 'data'"/>
  </xsl:function>

  <!-- Own text plus every attribute that carries a value. -->
  <xsl:template name="lossless-meta-generic">
    <xsl:param name="key" select="name()" as="xs:string"/>
    <xsl:variable name="own" select="normalize-space(string-join(text(), ' '))"/>
    <xsl:if test="$own">
      <field key="{$key}"><xsl:value-of select="$own"/></field>
    </xsl:if>
    <xsl:for-each select="@*[not(name() = $lossless.internal-atts)][not(contains(name(), ':'))][normalize-space()]">
      <field key="{$key}-{name()}"><xsl:value-of select="."/></field>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="*" mode="lossless-meta">
    <xsl:call-template name="lossless-meta-generic"/>
    <xsl:apply-templates select="*" mode="#current"/>
  </xsl:template>

  <!-- Keys the reader maps back to prolog elements. -->
  <xsl:template match="*[contains(@class, ' topic/permissions ')]" mode="lossless-meta">
    <field key="permissions"><xsl:value-of select="@view"/></field>
    <xsl:for-each select="@*[not(name() = ($lossless.internal-atts, 'view'))][normalize-space()]">
      <field key="permissions-{name()}"><xsl:value-of select="."/></field>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/audience ')]" mode="lossless-meta">
    <xsl:if test="@type">
      <field key="audience"><xsl:value-of select="@type"/></field>
    </xsl:if>
    <xsl:for-each select="@*[not(name() = ($lossless.internal-atts, 'type'))][normalize-space()]">
      <field key="audience-{name()}"><xsl:value-of select="."/></field>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/resourceid ')]" mode="lossless-meta">
    <xsl:if test="@appid">
      <field key="resourceid"><xsl:value-of select="@appid"/></field>
    </xsl:if>
    <xsl:for-each select="@*[not(name() = ($lossless.internal-atts, 'appid'))][normalize-space()]">
      <field key="resourceid-{name()}"><xsl:value-of select="."/></field>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/othermeta ')]" mode="lossless-meta">
    <field key="{if (normalize-space(@name)) then @name else 'othermeta'}"><xsl:value-of select="@content"/></field>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/data ')]" mode="lossless-meta">
    <xsl:variable name="key" select="if (normalize-space(@name)) then string(@name) else 'data'"/>
    <xsl:variable name="value" select="normalize-space(string-join((@value, text()), ' '))"/>
    <xsl:if test="$value">
      <field key="{$key}"><xsl:value-of select="$value"/></field>
    </xsl:if>
    <xsl:for-each select="@*[not(name() = ($lossless.internal-atts, 'name', 'value'))][normalize-space()]">
      <field key="{$key}-{name()}"><xsl:value-of select="."/></field>
    </xsl:for-each>
    <xsl:apply-templates select="*" mode="#current"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/copyright ')]" mode="lossless-meta">
    <field key="copyright">
      <xsl:value-of select="normalize-space(string-join((*[contains(@class, ' topic/copyryear ')]/@year, *[contains(@class, ' topic/copyrholder ')]), ' '))"/>
    </field>
    <xsl:if test="@type">
      <field key="copyright-type"><xsl:value-of select="@type"/></field>
    </xsl:if>
  </xsl:template>

  <!-- One entry per index path: "primary > secondary", with see and sort-as spelled out. -->
  <xsl:template match="*[contains(@class, ' topic/indexterm ')]" mode="lossless-meta">
    <xsl:param name="prefix" as="xs:string?"/>
    <xsl:variable name="label" select="normalize-space(string-join(text() | *[not(contains(@class, ' topic/indexterm ') or contains(@class, ' topic/index-base '))], ' '))"/>
    <xsl:variable name="path" select="string-join(($prefix, $label)[normalize-space()], ' &gt; ')"/>
    <xsl:variable name="extra" as="xs:string*">
      <xsl:for-each select="*[contains(@class, ' topic/index-base ')]">
        <xsl:sequence select="concat(name(), ': ', normalize-space(.))"/>
      </xsl:for-each>
      <xsl:for-each select="@start | @end | @keyref">
        <xsl:sequence select="concat(name(), ': ', .)"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:if test="empty(*[contains(@class, ' topic/indexterm ')]) or exists($extra)">
      <field key="indexterm">
        <xsl:value-of select="$path"/>
        <xsl:if test="exists($extra)">
          <xsl:value-of select="concat(' (', string-join($extra, '; '), ')')"/>
        </xsl:if>
      </field>
    </xsl:if>
    <xsl:apply-templates select="*[contains(@class, ' topic/indexterm ')]" mode="#current">
      <xsl:with-param name="prefix" select="$path"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Body copies of what the front matter already carries. -->
  <xsl:template match="*[contains(@class, ' topic/indexterm ')]" priority="20"/>
  <xsl:template match="*[contains(@class, ' topic/data-about ')]" priority="20"/>

  <!-- ============================================================== -->
  <!-- Topics and sections as Markdown DITA headings                  -->
  <!-- ============================================================== -->

  <xsl:variable name="lossless.reserved-classes" as="xs:string*"
                select="('section', 'example', 'task', 'concept', 'reference')"/>

  <!-- @outputclass values that can ride in a heading attribute block. -->
  <xsl:function name="ast:classes" as="xs:string*">
    <xsl:param name="element" as="element()"/>
    <xsl:sequence select="tokenize(normalize-space($element/@outputclass), ' ')[matches(., '^[A-Za-z][A-Za-z0-9_\-]*$')]
                                                                                 [not(. = $lossless.reserved-classes)]"/>
  </xsl:function>

  <!-- The class that makes the reader build a specialized topic.
       A task is read as a task at any depth. A concept or reference is
       typed only at the top and only without nested topics: the reader
       turns every "##" under such a topic into a section and rejects "###",
       so a nested topic there would not survive. -->
  <xsl:function name="ast:topic-type" as="xs:string?">
    <xsl:param name="topic" as="element()"/>
    <xsl:variable name="class" select="string($topic/@class)"/>
    <xsl:choose>
      <xsl:when test="contains($class, ' task/task ')">task</xsl:when>
      <xsl:when test="exists($topic/ancestor::*[contains(@class, ' topic/topic ')]) or
                      exists($topic/*[contains(@class, ' topic/topic ')])"/>
      <xsl:when test="contains($class, ' concept/concept ') and not(contains($class, ' glossentry/'))">concept</xsl:when>
      <xsl:when test="contains($class, ' reference/reference ')">reference</xsl:when>
    </xsl:choose>
  </xsl:function>

  <xsl:template name="ast-attibutes">
    <xsl:variable name="classes" select="tokenize(normalize-space(@class), '\s+')[. ne '']"/>
    <xsl:if test="normalize-space(@id) or exists($classes)">
      <xsl:text> {</xsl:text>
      <xsl:value-of select="string-join((if (normalize-space(@id)) then concat('#', @id) else (),
                                         for $c in $classes return concat('.', $c)), ' ')"/>
      <xsl:text>}</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- Topic titles: one heading level per level of nesting, six at most. -->
  <xsl:template match="*[contains(@class, ' topic/topic ')]/*[contains(@class, ' topic/title ')]" priority="20">
    <xsl:variable name="depth" select="count(ancestor::*[contains(@class, ' topic/topic ')])" as="xs:integer"/>
    <xsl:variable name="classes" select="(ast:topic-type(..), ast:classes(..))"/>
    <header level="{min(($depth, 6))}">
      <xsl:if test="normalize-space(../@id)">
        <xsl:attribute name="id" select="../@id"/>
      </xsl:if>
      <xsl:if test="exists($classes)">
        <xsl:attribute name="class" select="string-join($classes, ' ')"/>
      </xsl:if>
      <xsl:apply-templates/>
    </header>
  </xsl:template>

  <!-- Section titles. A section is a heading one level below its topic with
       the section or example class. The sections of a task use the titles
       that the reader's implicit-task-sections feature maps back to prereq,
       context, result and postreq. Where no heading level is left, the title
       is a bold paragraph. -->
  <xsl:template match="*" mode="dita2html:section-heading" priority="20">
    <xsl:param name="defaulttitle"/>
    <xsl:variable name="class" select="string(@class)"/>
    <xsl:variable name="title" select="*[contains(@class, ' topic/title ')][1]" as="element()?"/>
    <xsl:variable name="level" select="count(ancestor::*[contains(@class, ' topic/topic ')]) + 1" as="xs:integer"/>
    <xsl:variable name="in-task" select="contains(ancestor::*[contains(@class, ' topic/topic ')][1]/@class, ' task/task ')"/>
    <xsl:variable name="implicit" as="xs:string?"
                  select="if (contains($class, ' task/prereq ')) then 'Prerequisites'
                          else if (contains($class, ' task/context ')) then 'About this task'
                          else if (contains($class, ' task/result ')) then 'Verification'
                          else if (contains($class, ' task/postreq ')) then 'Next steps'
                          else ()"/>
    <xsl:variable name="content" as="node()*">
      <xsl:choose>
        <xsl:when test="exists($implicit)">
          <xsl:value-of select="$implicit"/>
        </xsl:when>
        <xsl:when test="exists($title)">
          <xsl:apply-templates select="$title/node()"/>
        </xsl:when>
        <xsl:when test="normalize-space(@spectitle)">
          <xsl:value-of select="@spectitle"/>
        </xsl:when>
        <xsl:when test="contains($class, ' task/tasktroubleshooting ')">Troubleshooting</xsl:when>
        <xsl:when test="contains($class, ' topic/example ')">Example</xsl:when>
        <xsl:when test="normalize-space($defaulttitle)">
          <xsl:value-of select="$defaulttitle"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="exists($content)">
      <xsl:choose>
        <xsl:when test="$level le 6 and exists($implicit) and $in-task">
          <header level="{$level}"><xsl:sequence select="$content"/></header>
        </xsl:when>
        <!-- In a task the reader accepts an example heading. Any other
             heading there opens a nested topic, so it stays a bold line. -->
        <xsl:when test="$level le 6 and contains($class, ' task/tasktroubleshooting ')">
          <header level="{$level}" class="section tasktroubleshooting"><xsl:sequence select="$content"/></header>
        </xsl:when>
        <xsl:when test="$level le 6 and (not($in-task) or contains($class, ' topic/example '))">
          <header level="{$level}">
            <xsl:if test="normalize-space(@id)">
              <xsl:attribute name="id" select="@id"/>
            </xsl:if>
            <xsl:attribute name="class"
                           select="string-join((if (contains($class, ' topic/example ')) then 'example' else 'section', ast:classes(.)), ' ')"/>
            <xsl:sequence select="$content"/>
          </header>
        </xsl:when>
        <xsl:otherwise>
          <para><strong><xsl:sequence select="$content"/></strong></para>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
    <!-- DITA allows more than one title; the base transform reports the rest and drops them. -->
    <xsl:for-each select="*[contains(@class, ' topic/title ')][position() gt 1]">
      <para><strong><xsl:apply-templates/></strong></para>
    </xsl:for-each>
  </xsl:template>

  <!-- Choices and choice tables carry their name as a class, which the
       reader maps back. -->
  <xsl:template match="*[contains(@class, ' task/choices ')]" priority="20">
    <bulletlist class="choices">
      <xsl:for-each select="*[contains(@class, ' task/choice ')]">
        <li><xsl:apply-templates/></li>
      </xsl:for-each>
    </bulletlist>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/choicetable ')]" priority="20">
    <table class="choicetable">
      <xsl:for-each select="*[contains(@class, ' task/chhead ')]">
        <thead>
          <tr>
            <xsl:for-each select="*">
              <tablecell><xsl:apply-templates/></tablecell>
            </xsl:for-each>
          </tr>
        </thead>
      </xsl:for-each>
      <tbody>
        <xsl:for-each select="*[contains(@class, ' task/chrow ')]">
          <tr>
            <xsl:for-each select="*">
              <tablecell><xsl:apply-templates/></tablecell>
            </xsl:for-each>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>

  <!-- The heading that tells the reader where the steps of a task begin. -->
  <xsl:template match="*[contains(@class, ' task/taskbody ')]/*[contains(@class, ' task/steps ') or contains(@class, ' task/steps-unordered ')]" priority="20">
    <xsl:variable name="level" select="count(ancestor::*[contains(@class, ' topic/topic ')]) + 1" as="xs:integer"/>
    <xsl:if test="$level le 6">
      <header level="{$level}">Procedure</header>
    </xsl:if>
    <xsl:next-match/>
  </xsl:template>

  <!-- ============================================================== -->
  <!-- Elements the base transform drops                              -->
  <!-- ============================================================== -->

  <!-- Templates in this file outrank the imported ones whatever their
       priority. The priorities only order the templates here. -->

  <xsl:template match="*[contains(@class, ' topic/draft-comment ')]" priority="20">
    <div>
      <para>
        <strong>Draft comment</strong>
        <xsl:for-each select="@author | @disposition | @time">
          <xsl:text> </xsl:text>
          <xsl:value-of select="concat(name(), ': ', .)"/>
        </xsl:for-each>
      </para>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/required-cleanup ')]" priority="20">
    <div>
      <para>
        <strong>Required cleanup</strong>
        <xsl:if test="@remap">
          <xsl:value-of select="concat(' remap: ', @remap)"/>
        </xsl:if>
      </para>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <!-- Foreign vocabularies have no Markdown form. The source markup is kept verbatim. -->
  <xsl:template match="*[contains(@class, ' topic/foreign ') or contains(@class, ' topic/unknown ')]
                        [not(contains(@class, ' ditaot-d/'))]" priority="20">
    <xsl:if test="node()">
      <xsl:variable name="markup" as="xs:string">
        <xsl:value-of>
          <xsl:apply-templates select="node()" mode="lossless-verbatim"/>
        </xsl:value-of>
      </xsl:variable>
      <codeblock class="xml" xml:space="preserve"><xsl:value-of select="replace($markup, '^\s+|\s+$', '')"/></codeblock>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="lossless-verbatim">
    <xsl:value-of select="concat('&lt;', name())"/>
    <xsl:for-each select="@*[not(name() = ('class', 'xtrf', 'xtrc'))]">
      <xsl:value-of select="concat(' ', name(), '=&quot;', replace(replace(replace(., '&amp;', '&amp;amp;'), '&lt;', '&amp;lt;'), '&quot;', '&amp;quot;'), '&quot;')"/>
    </xsl:for-each>
    <xsl:choose>
      <xsl:when test="node()">
        <xsl:text>&gt;</xsl:text>
        <xsl:apply-templates select="node()" mode="#current"/>
        <xsl:value-of select="concat('&lt;/', name(), '&gt;')"/>
      </xsl:when>
      <xsl:otherwise>/&gt;</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="text()" mode="lossless-verbatim">
    <xsl:value-of select="replace(replace(., '&amp;', '&amp;amp;'), '&lt;', '&amp;lt;')"/>
  </xsl:template>

  <!-- Footnotes: a reference where the footnote stands, with or without @id,
       so every definition at the end of the file has a reference. -->
  <xsl:template match="*[contains(@class, ' topic/fn ')][exists(@id)]" priority="20">
    <xsl:call-template name="topic.fn"/>
  </xsl:template>

  <!-- Descriptions: the base transform expects a caller to pull them, and
       for figures, tables, cross references and links none does. -->
  <xsl:template match="*[contains(@class, ' topic/fig ')][not(contains(@class, ' pr-d/syntaxdiagram '))]" priority="20">
    <xsl:variable name="title" select="*[contains(@class, ' topic/title ')]"/>
    <!-- The title rides on the first image as its Markdown title. Without an image it needs its own line. -->
    <xsl:if test="exists($title) and empty(*[contains(@class, ' topic/image ')])">
      <para><strong><xsl:apply-templates select="$title/node()"/></strong></para>
    </xsl:if>
    <xsl:next-match/>
    <xsl:for-each select="*[contains(@class, ' topic/desc ')]">
      <para><xsl:apply-templates/></para>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/figgroup ')]" priority="20">
    <div>
      <xsl:for-each select="*[contains(@class, ' topic/title ')]">
        <para><strong><xsl:apply-templates/></strong></para>
      </xsl:for-each>
      <xsl:apply-templates select="node() except *[contains(@class, ' topic/title ')]"/>
    </div>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/table ')]" priority="20">
    <xsl:for-each select="*[contains(@class, ' topic/title ')]">
      <para><strong><xsl:apply-templates/></strong></para>
    </xsl:for-each>
    <xsl:for-each select="*[contains(@class, ' topic/desc ')]">
      <para><xsl:apply-templates/></para>
    </xsl:for-each>
    <!-- One Markdown table per tgroup: column counts may differ between them. -->
    <xsl:for-each select="*[contains(@class, ' topic/tgroup ')]">
      <table>
        <xsl:apply-templates select="."/>
      </table>
    </xsl:for-each>
  </xsl:template>

  <!-- Preprocessing copies the target's short description into a link and
       marks the copy with a "genshortdesc" instruction. Only a description
       the author wrote is content of this topic. -->
  <xsl:function name="ast:authored-desc" as="element()*">
    <xsl:param name="link" as="element()"/>
    <xsl:sequence select="$link/*[contains(@class, ' topic/desc ')]
                                  [not(preceding-sibling::processing-instruction('ditaot')[1] = 'genshortdesc')]"/>
  </xsl:function>

  <xsl:template match="*[contains(@class, ' topic/xref ')]/*[contains(@class, ' topic/desc ')] |
                       *[contains(@class, ' topic/link ')]/*[contains(@class, ' topic/desc ')]" priority="20"/>

  <xsl:template match="*[contains(@class, ' topic/xref ')][exists(ast:authored-desc(.))]" priority="20">
    <xsl:next-match/>
    <xsl:text> (</xsl:text>
    <xsl:apply-templates select="ast:authored-desc(.)/node()"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/link ')][exists(ast:authored-desc(.))]" priority="20">
    <xsl:next-match/>
    <para>
      <xsl:apply-templates select="ast:authored-desc(.)/node()"/>
    </para>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/longquoteref ') or contains(@class, ' topic/longdescref ')]" priority="20">
    <xsl:if test="normalize-space(@href)">
      <xsl:text> </xsl:text>
      <link href="{@href}"><xsl:value-of select="@href"/></link>
    </xsl:if>
  </xsl:template>

  <!-- The image template turns longdescref into an attribute that Markdown has no slot for. -->
  <xsl:template match="*[contains(@class, ' topic/image ')][*[contains(@class, ' topic/longdescref ')] or @longdescref]" priority="20">
    <xsl:next-match/>
    <xsl:for-each select="*[contains(@class, ' topic/longdescref ')]/@href | @longdescref">
      <xsl:text> </xsl:text>
      <link href="{.}"><xsl:value-of select="."/></link>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/image ')]/*[contains(@class, ' topic/longdescref ')]" priority="21"/>
  <xsl:template match="*[contains(@class, ' topic/image ')]/@longdescref" priority="21"/>

  <!-- An image whose key did not resolve has no file to point at. Its alternative text is still content. -->
  <xsl:template match="*[contains(@class, ' topic/image ')][empty(@href)]" priority="25">
    <xsl:value-of select="normalize-space(string-join((*[contains(@class, ' topic/alt ')], @alt, @keyref)[normalize-space()][1], ''))"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/object ')]" priority="20">
    <para>
      <xsl:variable name="label" select="normalize-space(*[contains(@class, ' topic/desc ')])"/>
      <xsl:choose>
        <xsl:when test="normalize-space(@data)">
          <link href="{@data}"><xsl:value-of select="if ($label) then $label else @data"/></link>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$label"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:for-each select="@*[not(name() = ($lossless.internal-atts, 'data', 'id', 'outputclass'))][normalize-space()]">
        <xsl:value-of select="concat(' ', name(), ': ', .)"/>
      </xsl:for-each>
    </para>
    <xsl:if test="*[contains(@class, ' topic/param ')]">
      <bulletlist>
        <xsl:for-each select="*[contains(@class, ' topic/param ')]">
          <li><plain><xsl:value-of select="string-join(for $a in @*[not(name() = $lossless.internal-atts)] return concat(name($a), ': ', $a), ', ')"/></plain></li>
        </xsl:for-each>
      </bulletlist>
    </xsl:if>
    <xsl:apply-templates select="*[not(contains(@class, ' topic/desc ') or contains(@class, ' topic/param '))]"/>
  </xsl:template>

  <!-- Image map: the image, then each area as a link. -->
  <xsl:template match="*[contains(@class, ' ut-d/imagemap ')]" priority="30">
    <xsl:apply-templates select="*[contains(@class, ' topic/image ')]"/>
    <bulletlist>
      <xsl:for-each select="*[contains(@class, ' ut-d/area ')]">
        <li>
          <plain>
            <xsl:apply-templates select="*[contains(@class, ' topic/xref ')]"/>
            <xsl:value-of select="concat(' ', normalize-space(string-join((*[contains(@class, ' ut-d/shape ')], *[contains(@class, ' ut-d/coords ')]), ' ')))"/>
          </plain>
        </li>
      </xsl:for-each>
    </bulletlist>
    <xsl:apply-templates select="*[not(contains(@class, ' topic/image ') or contains(@class, ' ut-d/area '))]"/>
  </xsl:template>

  <!-- Definition lists stay definition lists, which the Markdown DITA reader
       reads as dl. Several terms for one definition share a line:
       the reader fails on some entries that have a term per line. A dlhead
       has no Markdown form and becomes a bold line above the list. -->
  <xsl:template match="*[contains(@class, ' topic/dl ')]" priority="20">
    <xsl:for-each select="*[contains(@class, ' topic/dlhead ')]">
      <para>
        <xsl:for-each select="*">
          <xsl:if test="position() gt 1"><xsl:text> / </xsl:text></xsl:if>
          <strong><xsl:apply-templates/></strong>
        </xsl:for-each>
      </para>
    </xsl:for-each>
    <definitionlist>
      <xsl:for-each select="*[contains(@class, ' topic/dlentry ')]">
        <dlentry>
          <dt>
            <xsl:for-each select="*[contains(@class, ' topic/dt ')]">
              <xsl:if test="position() gt 1"><xsl:text>, </xsl:text></xsl:if>
              <xsl:apply-templates/>
            </xsl:for-each>
          </dt>
          <xsl:for-each select="*[contains(@class, ' topic/dd ')]">
            <dd><xsl:apply-templates/></dd>
          </xsl:for-each>
          <xsl:if test="empty(*[contains(@class, ' topic/dd ')])">
            <dd/>
          </xsl:if>
        </dlentry>
      </xsl:for-each>
    </definitionlist>
  </xsl:template>

  <!-- Notes as admonitions. This template only records the type and title;
       the syntax is written by the admonition style (see ast2markdown-lossless.xsl).
       Hazard statements keep the base rendering. -->
  <xsl:template match="*[contains(@class, ' topic/note ')][not(contains(@class, ' hazard-d/hazardstatement '))]" priority="20">
    <xsl:variable name="type" select="if (normalize-space(@type)) then normalize-space(@type) else 'note'"/>
    <xsl:variable name="other" select="normalize-space(@othertype)"/>
    <admonition>
      <xsl:choose>
        <xsl:when test="$type = 'other' and matches($other, '^[A-Za-z][A-Za-z0-9_\-]*$')">
          <xsl:attribute name="type" select="$other"/>
        </xsl:when>
        <xsl:when test="$type = 'other' and $other">
          <xsl:attribute name="type" select="'other'"/>
          <xsl:attribute name="title" select="$other"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="type" select="$type"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="normalize-space(@spectitle)">
        <xsl:attribute name="title" select="normalize-space(@spectitle)"/>
      </xsl:if>
      <xsl:apply-templates/>
    </admonition>
  </xsl:template>

  <!-- The flatten pass decides what is a block from these two functions. -->
  <xsl:function name="ast:is-block" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="exists($node/(self::plain | self::para | self::codeblock | self::rawblock | self::blockquote |
                                        self::orderedlist | self::bulletlist | self::definitionlist | self::dlentry |
                                        self::dt | self::dd | self::header | self::horizontalrule | self::table |
                                        self::thead | self::tbody | self::tr | self::tablecell | self::div |
                                        self::footnoteblock | self::null | self::admonition))"/>
  </xsl:function>

  <xsl:function name="ast:is-container-block" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="exists($node/(self::rawblock | self::blockquote | self::li | self::dd | self::div |
                                        self::null | self::admonition))"/>
  </xsl:function>

  <!-- Underline has no Markdown syntax. Inline HTML keeps it, and the reader
       maps it back to u. Strikethrough is "~~text~~", read as line-through. -->
  <xsl:template match="*[contains(@class, ' hi-d/u ')]" priority="20">
    <htmlinline name="u"><xsl:apply-templates/></htmlinline>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' hi-d/line-through ')]" priority="20">
    <strikeout><xsl:apply-templates/></strikeout>
  </xsl:template>

  <!-- Properties: a property may omit its type, value or description. Each
       cell goes under its own heading, not into the first free column. -->
  <xsl:template match="*[contains(@class, ' reference/properties ')]" priority="20">
    <xsl:variable name="cols" as="xs:string+" select="(' reference/proptype ', ' reference/propvalue ', ' reference/propdesc ')"/>
    <xsl:variable name="heads" as="xs:string+" select="(' reference/proptypehd ', ' reference/propvaluehd ', ' reference/propdeschd ')"/>
    <xsl:variable name="props" select="."/>
    <xsl:variable name="used" as="xs:integer*"
                  select="for $i in 1 to 3 return
                          if ($props/*/*[contains(@class, $cols[$i]) or contains(@class, $heads[$i])]) then $i else ()"/>
    <table>
      <thead>
        <tr>
          <xsl:for-each select="$used">
            <xsl:variable name="i" select="."/>
            <tablecell>
              <xsl:apply-templates select="$props/*[contains(@class, ' reference/prophead ')]/*[contains(@class, $heads[$i])]/node()"/>
            </tablecell>
          </xsl:for-each>
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="*[contains(@class, ' reference/property ')]">
          <xsl:variable name="row" select="."/>
          <tr>
            <xsl:for-each select="$used">
              <xsl:variable name="i" select="."/>
              <tablecell>
                <xsl:apply-templates select="$row/*[contains(@class, $cols[$i])]/node()"/>
              </tablecell>
            </xsl:for-each>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>

  <!-- ============================================================== -->
  <!-- References kept as authored                                    -->
  <!-- ============================================================== -->

  <!-- An element that still has its conref was not resolved, because
       markdown.conref is keep. It is written as raw DITA, which the Markdown
       DITA parser reads back as the same element and attributes. -->
  <xsl:template match="*[@conref]" priority="60">
    <xsl:choose>
      <xsl:when test="ast:is-phrase(.)">
        <rawinline>
          <xsl:value-of select="ast:raw-dita(.)"/>
        </rawinline>
      </xsl:when>
      <xsl:otherwise>
        <rawblock>
          <xsl:value-of select="ast:raw-dita(.)"/>
        </rawblock>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- A DITA href whose target is not part of the conversion keeps the file
       name and fragment the author wrote. The target has no Markdown file to
       point to, and the parser reads the href back unchanged. -->
  <xsl:template match="*[ast:is-unconverted-target(.)]" mode="determine-final-href" priority="10">
    <xsl:value-of select="@href"/>
  </xsl:template>

  <!-- A reference within the topic keeps its topic ID. Without it, "#element"
       reads back as a reference to a topic with that ID. -->
  <xsl:template match="*[starts-with(normalize-space(@href), '#')]
                        [empty(@format) or @format = 'dita']" mode="determine-final-href" priority="10">
    <xsl:value-of select="normalize-space(@href)"/>
  </xsl:template>

  <!-- Without link text the Markdown link would show the href instead, which
       the parser reads back as authored text. Raw DITA keeps the link empty. -->
  <xsl:template match="*[contains(@class, ' topic/xref ')]
                        [ast:is-unconverted-target(.)]
                        [empty(node()[self::* or self::text()[normalize-space()]])]" priority="40">
    <rawinline>
      <xsl:value-of select="ast:raw-dita(.)"/>
    </rawinline>
  </xsl:template>

  <!-- Related links are copied into a temporary tree before they are written,
       which has no base URI. They resolve against the topic document instead. -->
  <xsl:variable name="ast:document-base" select="base-uri(/)" as="xs:anyURI?"/>

  <xsl:function name="ast:is-unconverted-target" as="xs:boolean">
    <xsl:param name="link" as="element()"/>
    <xsl:variable name="base" select="(base-uri($link)[string(.) ne ''], $ast:document-base)[1]" as="xs:anyURI?"/>
    <xsl:variable name="href" select="normalize-space($link/@href)" as="xs:string"/>
    <xsl:variable name="file" select="if (contains($href, '#')) then substring-before($href, '#') else $href" as="xs:string"/>
    <xsl:sequence select="$file ne '' and
                          not(matches($file, '^[a-zA-Z][a-zA-Z0-9+.\-]*:')) and
                          (empty($link/@scope) or $link/@scope = ('local', 'peer')) and
                          (empty($link/@format) or $link/@format = ('dita', 'ditamap')) and
                          exists($base) and
                          not(unparsed-text-available(resolve-uri($file, $base)))"/>
  </xsl:function>

  <!-- Phrase-level elements sit in a line of text; everything else is a block. -->
  <xsl:function name="ast:is-phrase" as="xs:boolean">
    <xsl:param name="element" as="element()"/>
    <xsl:variable name="class" select="string($element/@class)" as="xs:string"/>
    <xsl:sequence select="some $token in (' topic/ph ', ' topic/keyword ', ' topic/term ', ' topic/xref ',
                                          ' topic/text ', ' topic/tm ', ' topic/cite ', ' topic/q ',
                                          ' topic/boolean ', ' topic/state ', ' topic/indexterm ')
                          satisfies contains($class, $token) or
                          (contains($class, ' topic/image ') and not($element/@placement = 'break'))"/>
  </xsl:function>

  <!-- The element as the author wrote it, on one line. Attributes that
       preprocessing adds are left out, and line breaks become character
       references so that the element stays a single Markdown line. -->
  <xsl:function name="ast:raw-dita" as="xs:string">
    <xsl:param name="element" as="element()"/>
    <xsl:value-of>
      <xsl:apply-templates select="$element" mode="lossless-raw-dita"/>
    </xsl:value-of>
  </xsl:function>

  <xsl:template match="*" mode="lossless-raw-dita">
    <xsl:variable name="content" as="node()*"
                  select="node()[self::* and empty(self::*[contains(@class, ' ditaot-d/')]) or self::text()]"/>
    <xsl:text>&lt;</xsl:text>
    <xsl:value-of select="name()"/>
    <xsl:for-each select="@*[namespace-uri() = ('', 'http://www.w3.org/XML/1998/namespace')]
                            [not(name() = ('class', 'xtrf', 'xtrc', 'domains', 'specializations'))]">
      <xsl:value-of select="concat(' ', name(), '=&quot;', ast:raw-escape(., true()), '&quot;')"/>
    </xsl:for-each>
    <xsl:choose>
      <xsl:when test="empty($content[self::* or normalize-space()])">
        <xsl:text>/&gt;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>&gt;</xsl:text>
        <xsl:apply-templates select="$content" mode="lossless-raw-dita"/>
        <xsl:value-of select="concat('&lt;/', name(), '&gt;')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="text()" mode="lossless-raw-dita">
    <xsl:value-of select="ast:raw-escape(., false())"/>
  </xsl:template>

  <xsl:function name="ast:raw-escape" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="attribute" as="xs:boolean"/>
    <xsl:variable name="markup" select="replace(replace(replace($text, '&amp;', '&amp;amp;'), '&lt;', '&amp;lt;'), '&gt;', '&amp;gt;')"/>
    <xsl:variable name="breaks" select="replace(replace(replace($markup, '&#13;', '&amp;#13;'), '&#10;', '&amp;#10;'), '&#9;', if ($attribute) then '&amp;#9;' else '&#9;')"/>
    <xsl:sequence select="if ($attribute) then replace($breaks, '&quot;', '&amp;quot;') else $breaks"/>
  </xsl:function>

</xsl:stylesheet>
