package com.elovirta.dita.markdown;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import com.elovirta.dita.utils.ClasspathURIResolver;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringReader;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMResult;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.sax.SAXSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.w3c.dom.Attr;
import org.w3c.dom.Document;
import org.xml.sax.InputSource;
import org.xmlunit.builder.DiffBuilder;
import org.xmlunit.diff.DefaultComparisonFormatter;
import org.xmlunit.diff.Diff;

/**
 * Writes DITA with the stylesheet of the markdown transtype and reads the Markdown back with the
 * Markdown DITA parser.
 */
public class LosslessWriterTest {

  private final TransformerFactory transformerFactory;

  public LosslessWriterTest() {
    transformerFactory = TransformerFactory.newInstance();
    transformerFactory.setURIResolver(new ClasspathURIResolver(transformerFactory.getURIResolver()));
  }

  @ParameterizedTest
  @ValueSource(strings = { "raw_dita", "raw_dita_fallback" })
  public void testWrite(final String name) throws Exception {
    assertEquals(read("output/markdown_lossless/" + name + ".md"), write("dita/lossless/" + name + ".dita"));
  }

  /** The Markdown reads back as the source, except for IDs that the parser generates for sections. */
  @ParameterizedTest
  @ValueSource(strings = { "raw_dita" })
  public void testRoundTrip(final String name) throws Exception {
    final DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
    factory.setNamespaceAware(true);
    final Document act = factory.newDocumentBuilder().newDocument();
    final InputSource in = new InputSource(new StringReader(read("output/markdown_lossless/" + name + ".md")));
    in.setSystemId("classpath:/output/markdown_lossless/" + name + ".md");
    transformerFactory.newTransformer().transform(new SAXSource(new MarkdownReader(), in), new DOMResult(act));
    final Document exp;
    try (InputStream src = getClass().getResourceAsStream("/dita/lossless/" + name + ".dita")) {
      exp = factory.newDocumentBuilder().parse(src);
    }

    final Diff diff = DiffBuilder
      .compare(exp)
      .withTest(act)
      .ignoreWhitespace()
      .ignoreComments()
      .normalizeWhitespace()
      .withAttributeFilter(LosslessWriterTest::isCompared)
      .checkForSimilar()
      .build();
    if (diff.hasDifferences()) {
      System.err.println(diff.fullDescription(new DefaultComparisonFormatter()));
      final StringWriter buf = new StringWriter();
      transformerFactory.newTransformer().transform(new DOMSource(act), new StreamResult(buf));
      System.err.println(buf);
    }
    assertFalse(diff.hasDifferences());
  }

  private static boolean isCompared(final Attr attr) {
    return !(attr.getName().equals("id") && attr.getOwnerElement().getTagName().equals("section"));
  }

  private String write(final String input) throws Exception {
    final StringWriter act = new StringWriter();
    try (InputStream style = getClass().getResourceAsStream("/dita2markdown-lossless.xsl")) {
      final Transformer t = transformerFactory.newTransformer(
        new StreamSource(style, "classpath:///dita2markdown-lossless.xsl")
      );
      // A file URI, so that the stylesheet can check which link targets exist.
      t.transform(new StreamSource(getClass().getResource("/" + input).toString()), new StreamResult(act));
    }
    return act.toString();
  }

  private String read(final String input) throws IOException {
    try (InputStream in = getClass().getResourceAsStream("/" + input)) {
      return new String(in.readAllBytes(), StandardCharsets.UTF_8);
    }
  }
}
