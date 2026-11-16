package com.elovirta.dita.markdown.verify;

import com.elovirta.dita.markdown.MarkdownReader;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.xml.parsers.SAXParserFactory;
import org.xml.sax.Attributes;
import org.xml.sax.ErrorHandler;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import org.xml.sax.XMLReader;
import org.xml.sax.helpers.DefaultHandler;

/**
 * Compares a DITA topic with the Markdown DITA file generated from it and lists the
 * source text that is missing from the output.
 *
 * <p>Each text node of the topic is reduced to its letters and digits. That
 * string has to appear in the output, reduced the same way, at least as many
 * times as the source has nodes with that string. Spacing and punctuation are
 * left out of the comparison because the conversion changes both: it escapes
 * characters, adds quotation marks and joins or separates inline elements.
 * The output is looked at twice: as the characters in the file, and as the
 * text the Markdown DITA parser reads from it. The second view catches text that is in
 * the file but that Markdown syntax hides, such as a table cell beyond the
 * header width or a paragraph swallowed by an unclosed code fence.</p>
 *
 * <p>Not compared: markup, element order, attributes that carry no prose, and
 * text that preprocessing generated from other topics (link text and link
 * descriptions marked with a <code>ditaot</code> processing instruction).
 * A text node of one or two characters matches easily by accident, so the
 * check is weakest for those.</p>
 */
public final class LosslessCheck {

  /** A piece of source text and where it came from. */
  public static final class Item {

    public final String path;
    public final String text;
    final String phrase;

    Item(String path, String text) {
      this.path = path;
      this.text = text;
      this.phrase = phrase(text);
    }

    @Override
    public String toString() {
      final String shown = text.length() > 100 ? text.substring(0, 100) + "..." : text;
      return path + ": " + shown;
    }
  }

  /** The outcome for one topic. */
  public static final class Result {

    public final File source;
    public final File output;
    /** Source text absent from the characters of the output file. */
    public final List<Item> missingFromFile = new ArrayList<>();
    /** Source text absent from what the Markdown DITA parser reads. */
    public final List<Item> missingAfterParse = new ArrayList<>();
    /** External link targets absent from the output file. */
    public final List<Item> missingLinks = new ArrayList<>();
    /**
     * Text of the authored file that preprocessing removed before the
     * conversion ran: filtered by a DITAVAL file, replaced by a resolved
     * conref or key, or deleted with an element whose conref target was not
     * found. Expected for the first two, a loss for the last.
     */
    public final List<Item> removedBefore = new ArrayList<>();
    /** Set when the output file is absent or the parser rejects it. */
    public String failure;
    public int checked;

    Result(File source, File output) {
      this.source = source;
      this.output = output;
    }

    public boolean passed() {
      return failure == null && missingFromFile.isEmpty() && missingAfterParse.isEmpty() && missingLinks.isEmpty();
    }
  }

  private static final Pattern NOT_WORD = Pattern.compile("[^\\p{L}\\p{N}]+");
  private static final Pattern ESCAPE = Pattern.compile("\\\\(\\p{Punct})");
  /** Numeric references stand for line breaks and spaces in the HTML that tables are written in. */
  private static final Pattern CHARACTER_REFERENCE = Pattern.compile("&#(?:[0-9]+|x[0-9A-Fa-f]+);");
  private static final Pattern ABSOLUTE = Pattern.compile("^[A-Za-z][A-Za-z0-9+.\\-]*:.*");

  /** Attributes whose value is prose, on any element. */
  private static final Set<String> TEXT_ATTRIBUTES = Set.of("alt", "spectitle", "othertype", "reftitle");
  /** Attributes that are never content. */
  private static final Set<String> INTERNAL_ATTRIBUTES = Set.of(
    "class",
    "xtrf",
    "xtrc",
    "domains",
    "specializations",
    "ditaarch:DITAArchVersion",
    "xml:lang",
    "translate",
    "dir",
    "id"
  );
  /** Attributes read back from the parsed output. Generated ids are left out: they repeat title words. */
  private static final Set<String> PARSED_ATTRIBUTES = Set.of(
    "alt",
    "name",
    "value",
    "content",
    "view",
    "appid",
    "type",
    "href",
    "keyref",
    "spectitle",
    "othertype",
    "reftitle",
    "callout",
    "outputclass"
  );

  private LosslessCheck() {}

  public static Result check(File source, File output) {
    return check(source, output, null);
  }

  /**
   * @param source   the topic after preprocessing, from the temporary directory
   * @param output   the Markdown DITA file generated from it
   * @param authored the topic as the author wrote it, or null to skip the comparison with it
   */
  public static Result check(File source, File output, File authored) {
    final Result result = new Result(source, output);
    final List<Item> items = new ArrayList<>();
    final List<Item> links = new ArrayList<>();
    try {
      readSource(source, items, links);
    } catch (Exception e) {
      result.failure = "Cannot read source topic: " + e;
      return result;
    }
    if (authored != null && authored.isFile()) {
      try {
        final List<Item> written = new ArrayList<>();
        readSource(authored, written, new ArrayList<>());
        final StringBuilder kept = new StringBuilder();
        for (Item item : items) {
          kept.append(item.phrase).append('\u0000');
        }
        compare(written, kept.toString(), result.removedBefore);
      } catch (Exception e) {
        // Not XML, or not parseable without its DTD: nothing to compare.
      }
    }
    result.checked = items.size();
    if (!output.isFile()) {
      result.failure = "No output file";
      result.missingFromFile.addAll(items);
      return result;
    }
    final String file;
    try {
      file = new String(Files.readAllBytes(output.toPath()), StandardCharsets.UTF_8);
    } catch (IOException e) {
      result.failure = "Cannot read output file: " + e;
      return result;
    }
    final String plain = ESCAPE
      .matcher(file)
      .replaceAll("$1")
      .replace("&lt;", "<")
      .replace("&gt;", ">")
      .replace("&quot;", "\"")
      .replace("&amp;", "&");
    // Tables written as HTML hold line breaks and spaces as numeric references.
    // Source text can also contain such a reference literally, so both readings count.
    final String decoded = CHARACTER_REFERENCE.matcher(plain).replaceAll(" ");
    compare(items, phrase(plain) + '\u0000' + phrase(decoded), result.missingFromFile);
    for (Item link : links) {
      if (!file.contains(link.text) && !plain.contains(link.text) && !file.contains(encode(link.text))) {
        result.missingLinks.add(link);
      }
    }
    try {
      compare(items, phrase(readParsed(output)), result.missingAfterParse);
    } catch (Throwable e) {
      Throwable cause = e;
      while (cause.getCause() != null) {
        cause = cause.getCause();
      }
      result.failure = "Markdown DITA parser rejected the output: " + cause;
    }
    return result;
  }

  /** The letters and digits of the text, in order, with everything else removed. */
  static String phrase(String text) {
    return NOT_WORD.matcher(text).replaceAll("");
  }

  private static void compare(List<Item> items, String haystack, List<Item> missing) {
    final Map<String, List<Item>> byPhrase = new LinkedHashMap<>();
    for (Item item : items) {
      byPhrase.computeIfAbsent(item.phrase, k -> new ArrayList<>()).add(item);
    }
    for (Map.Entry<String, List<Item>> e : byPhrase.entrySet()) {
      final int found = count(haystack, e.getKey(), e.getValue().size());
      final List<Item> wanted = e.getValue();
      for (int i = found; i < wanted.size(); i++) {
        missing.add(wanted.get(i));
      }
    }
  }

  /** Occurrences of the phrase that do not overlap, up to the limit. */
  private static int count(String haystack, String phrase, int limit) {
    int n = 0;
    int from = 0;
    while (n < limit) {
      final int at = haystack.indexOf(phrase, from);
      if (at < 0) {
        break;
      }
      n++;
      from = at + phrase.length();
    }
    return n;
  }

  private static String encode(String href) {
    return href.replace(" ", "%20").replace("(", "%28").replace(")", "%29").replace("<", "%3C").replace(">", "%3E");
  }

  private static void readSource(File source, List<Item> items, List<Item> links) throws Exception {
    final SAXParserFactory factory = SAXParserFactory.newInstance();
    factory.setNamespaceAware(false);
    factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
    factory
      .newSAXParser()
      .parse(
        source,
        new DefaultHandler() {
          private final Deque<String> names = new ArrayDeque<>();
          private final Deque<StringBuilder> text = new ArrayDeque<>();
          private int generated = 0;
          private int prolog = 0;
          /** Depth at which a "gentext" instruction was seen: the rest of that element is generated. */
          private final Deque<Integer> generatedRest = new ArrayDeque<>();
          private boolean generatedNext = false;

          private String path() {
            final StringBuilder buf = new StringBuilder();
            for (final java.util.Iterator<String> it = names.descendingIterator(); it.hasNext();) {
              if (buf.length() > 0) {
                buf.append('/');
              }
              buf.append(it.next());
            }
            return buf.toString();
          }

          private void flush() {
            final StringBuilder buf = text.peek();
            if (buf != null && buf.length() > 0) {
              add(items, path(), buf.toString());
              buf.setLength(0);
            }
          }

          @Override
          public void startElement(String uri, String localName, String qName, Attributes atts) {
            flush();
            final String cls = atts.getValue("class");
            // Flagging markup and copied link descriptions that preprocessing inserts are not source content.
            if (generated > 0 || generatedNext || (cls != null && cls.contains(" ditaot-d/"))) {
              generated++;
            }
            generatedNext = false;
            if (prolog > 0 || (cls != null && cls.contains(" topic/prolog "))) {
              prolog++;
            }
            names.push(qName);
            text.push(new StringBuilder());
            if (generated > 0) {
              return;
            }
            final boolean named =
              cls != null &&
              (
                cls.contains(" topic/data ") ||
                cls.contains(" topic/othermeta ") ||
                cls.contains(" topic/param ") ||
                cls.contains(" topic/state ")
              );
            for (int i = 0; i < atts.getLength(); i++) {
              final String name = atts.getQName(i);
              final String value = atts.getValue(i);
              if (INTERNAL_ATTRIBUTES.contains(name) || name.startsWith("xmlns")) {
                continue;
              }
              final boolean content =
                TEXT_ATTRIBUTES.contains(name) ||
                (prolog > 1) ||
                (named && (name.equals("name") || name.equals("value") || name.equals("content")));
              if (content) {
                add(items, path() + "/@" + name, value);
              }
              if (
                name.equals("href") &&
                !value.isEmpty() &&
                ("external".equals(atts.getValue("scope")) || ABSOLUTE.matcher(value).matches()) &&
                !value.startsWith("file:")
              ) {
                links.add(new Item(path() + "/@href", value));
              }
            }
          }

          @Override
          public void endElement(String uri, String localName, String qName) {
            flush();
            if (!generatedRest.isEmpty() && generatedRest.peek() == names.size()) {
              generatedRest.pop();
              generated--;
            }
            names.pop();
            text.pop();
            if (generated > 0) {
              generated--;
            }
            if (prolog > 0) {
              prolog--;
            }
          }

          @Override
          public void processingInstruction(String target, String data) {
            if (!"ditaot".equals(target) || generated > 0) {
              return;
            }
            if ("gentext".equals(data)) {
              flush();
              generatedRest.push(names.size());
              generated++;
            } else if ("genshortdesc".equals(data)) {
              flush();
              generatedNext = true;
            }
          }

          @Override
          public void characters(char[] ch, int start, int length) {
            if (generated == 0 && !text.isEmpty()) {
              text.peek().append(ch, start, length);
            }
          }
        }
      );
  }

  private static void add(List<Item> items, String path, String text) {
    final Item item = new Item(path, text.trim().replaceAll("\\s+", " "));
    if (!item.phrase.isEmpty()) {
      items.add(item);
    }
  }

  /** Text and text-bearing attributes of the DITA that the Markdown DITA parser produces from the file. */
  private static String readParsed(File output) throws Exception {
    final StringBuilder buf = new StringBuilder();
    final StringBuilder attributes = new StringBuilder();
    final XMLReader reader = new MarkdownReader();
    // As plugin.xml configures the md and markdown formats.
    reader.setFeature("http://lwdita.org/sax/features/implicit-task-sections", true);
    reader.setErrorHandler(
      new ErrorHandler() {
        @Override
        public void warning(SAXParseException e) {}

        @Override
        public void error(SAXParseException e) throws SAXException {
          throw e;
        }

        @Override
        public void fatalError(SAXParseException e) throws SAXException {
          throw e;
        }
      }
    );
    reader.setContentHandler(
      new DefaultHandler() {
        @Override
        public void startElement(String uri, String localName, String qName, Attributes atts) {
          buf.append(' ');
          for (int i = 0; i < atts.getLength(); i++) {
            if (PARSED_ATTRIBUTES.contains(atts.getQName(i))) {
              // Kept apart from the text: a value in the middle of a sentence would split it.
              attributes.append(atts.getValue(i)).append('\u0000');
            }
          }
        }

        @Override
        public void endElement(String uri, String localName, String qName) {
          buf.append(' ');
        }

        @Override
        public void characters(char[] ch, int start, int length) {
          buf.append(ch, start, length);
        }
      }
    );
    reader.parse(new InputSource(output.toURI().toString()));
    return buf.append('\u0000').append(attributes).toString();
  }

  /** Report for a set of results; empty when all passed. */
  public static String report(List<Result> results) {
    final StringBuilder buf = new StringBuilder();
    for (Result r : results) {
      if (r.passed()) {
        continue;
      }
      buf.append(r.source.getName()).append(" -> ").append(r.output.getPath()).append('\n');
      if (r.failure != null) {
        buf.append("  ").append(r.failure).append('\n');
      }
      section(buf, "Missing from the file", r.missingFromFile);
      final List<Item> hidden = new ArrayList<>(r.missingAfterParse);
      hidden.removeAll(r.missingFromFile);
      section(buf, "In the file, but not read by the Markdown DITA parser", hidden);
      section(buf, "External link targets missing", r.missingLinks);
    }
    return buf.toString();
  }

  /** Text that preprocessing removed, per topic; empty when there is none. */
  public static String reportRemoved(List<Result> results) {
    final StringBuilder buf = new StringBuilder();
    for (Result r : results) {
      if (!r.removedBefore.isEmpty()) {
        buf.append(r.source.getName()).append('\n');
        section(buf, "Removed by preprocessing (filtering, conref or key resolution)", r.removedBefore);
      }
    }
    return buf.toString();
  }

  private static void section(StringBuilder buf, String title, List<Item> items) {
    if (items.isEmpty()) {
      return;
    }
    buf.append("  ").append(title).append(" (").append(items.size()).append("):\n");
    for (Item item : items) {
      buf.append("    ").append(item).append('\n');
    }
  }

  /** Usage: LosslessCheck source.dita output.md [source.dita output.md ...] */
  public static void main(String[] args) {
    final List<Result> results = new ArrayList<>();
    for (int i = 0; i + 1 < args.length; i += 2) {
      results.add(check(new File(args[i]), new File(args[i + 1])));
    }
    final String report = report(results);
    System.out.print(report);
    final long failed = results.stream().filter(r -> !r.passed()).count();
    System.out.println(results.size() + " topics compared, " + failed + " with missing text");
    System.exit(failed == 0 ? 0 : 1);
  }
}
