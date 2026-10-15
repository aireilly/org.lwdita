package com.elovirta.dita.markdown;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import com.elovirta.dita.utils.ClasspathURIResolver;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMResult;
import javax.xml.transform.sax.SAXSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import org.junit.jupiter.api.Test;
import org.w3c.dom.Attr;
import org.w3c.dom.Document;
import org.xml.sax.InputSource;
import org.xmlunit.builder.DiffBuilder;
import org.xmlunit.diff.DefaultComparisonFormatter;
import org.xmlunit.diff.Diff;

/**
 * Writes DITA to Markdown with raw DITA passthrough enabled, then reads the Markdown back with the
 * raw-dita reader feature and compares the result with the source.
 */
public class RawDitaRoundTripTest {

  private static final String SRC = "dita/raw_dita.dita";
  private static final String MARKDOWN = "output/markdown/raw_dita.md";

  private final TransformerFactory transformerFactory;

  public RawDitaRoundTripTest() {
    transformerFactory = TransformerFactory.newInstance();
    transformerFactory.setURIResolver(new ClasspathURIResolver(transformerFactory.getURIResolver()));
  }

  @Test
  public void testWrite() throws Exception {
    assertEquals(new String(read(MARKDOWN), StandardCharsets.UTF_8), write(SRC, "/dita2markdown-raw.xsl"));
  }

  /**
   * Elements whose raw form would be dropped, duplicated, published against DRAFT, or restructured by
   * the reader's HTML5 parser keep their normal Markdown output.
   */
  @Test
  public void testFallback() throws Exception {
    final String input = "dita/raw_dita_fallback.dita";
    assertEquals(write(input, "/dita2markdown_template.xsl"), write(input, "/dita2markdown-raw.xsl"));
  }

  private String write(final String input, final String xslPath) throws Exception {
    final StringWriter act = new StringWriter();
    try (
      InputStream style = getClass().getResourceAsStream(xslPath);
      InputStream in = getClass().getResourceAsStream("/" + input)
    ) {
      final Transformer t = transformerFactory.newTransformer(new StreamSource(style, "classpath://" + xslPath));
      t.transform(new StreamSource(in), new StreamResult(act));
    }
    return act.toString();
  }

  @Test
  public void testRoundTrip() throws Exception {
    final DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
    factory.setNamespaceAware(true);
    final MarkdownReader reader = new MarkdownReader();
    reader.setFeature("http://lwdita.org/sax/features/raw-dita", true);
    final Document act = factory.newDocumentBuilder().newDocument();
    try (InputStream in = getClass().getResourceAsStream("/" + MARKDOWN)) {
      final InputSource i = new InputSource(in);
      i.setSystemId(URI.create("classpath:/" + MARKDOWN).toString());
      transformerFactory.newTransformer().transform(new SAXSource(reader, i), new DOMResult(act));
    }
    final Document exp;
    try (InputStream in = getClass().getResourceAsStream("/" + SRC)) {
      exp = factory.newDocumentBuilder().parse(in);
    }

    final Diff diff = DiffBuilder
      .compare(exp)
      .withTest(act)
      .ignoreWhitespace()
      .ignoreComments()
      .normalizeWhitespace()
      .withAttributeFilter(RawDitaRoundTripTest::isCompared)
      .checkForSimilar()
      .build();
    if (diff.hasDifferences()) {
      System.err.println(diff.fullDescription(new DefaultComparisonFormatter()));
    }
    assertFalse(diff.hasDifferences());
  }

  /**
   * The reader generates section IDs from titles, and table IDs are not preserved because tables are
   * never written as raw DITA.
   */
  private static boolean isCompared(final Attr attr) {
    if (!attr.getName().equals("id")) {
      return true;
    }
    final String name = attr.getOwnerElement().getTagName();
    return !(name.equals("section") || name.equals("table"));
  }

  private byte[] read(final String input) throws IOException {
    try (InputStream in = getClass().getResourceAsStream("/" + input)) {
      return in.readAllBytes();
    }
  }
}
