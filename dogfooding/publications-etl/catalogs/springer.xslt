<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <xsl:for-each select="document">
      <xsl:apply-templates select="citations"/>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="citations">
    <xsl:for-each select="author">
      <name>
        <first>
          <xsl:value-of select="normalize-space(f)"/>
        </first>
        <last>
          <xsl:value-of select="normalize-space(l)"/>
        </last>
      </name>
      <affiliations>
        <ul>
          <xsl:for-each select="group">
            <li>
              <xsl:value-of select="normalize-space(name)"/>
            </li>
          </xsl:for-each>
        </ul>
      </affiliations>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>