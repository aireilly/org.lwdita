<?xml version="1.0" encoding="UTF-8"?>
<!-- DITA to Markdown through the shipped Markdown stylesheet, with raw DITA
     passthrough enabled. -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

  <xsl:import href="dita2markdown_template.xsl"/>

  <xsl:param name="raw-dita" select="'yes'"/>

</xsl:stylesheet>
