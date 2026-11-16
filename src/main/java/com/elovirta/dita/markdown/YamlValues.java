package com.elovirta.dita.markdown;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Finishes the values that the flexmark front matter parser returns. That
 * parser splits lines into keys and values and leaves the values as typed,
 * so a quoted scalar keeps its quotes and a flow sequence such as
 * <code>[a, b]</code> stays one string.
 */
public final class YamlValues {

  private YamlValues() {}

  public static Map<String, List<String>> normalize(final Map<String, List<String>> data) {
    final Map<String, List<String>> res = new LinkedHashMap<>();
    for (Map.Entry<String, List<String>> e : data.entrySet()) {
      final List<String> values = new ArrayList<>();
      for (String value : e.getValue()) {
        final String v = value == null ? "" : value.trim();
        if (e.getValue().size() == 1 && v.length() >= 2 && v.startsWith("[") && v.endsWith("]")) {
          for (String item : split(v.substring(1, v.length() - 1))) {
            values.add(unquote(item));
          }
        } else {
          values.add(unquote(v));
        }
      }
      res.put(e.getKey(), values);
    }
    return res;
  }

  /** Splits a flow sequence at the commas that are outside quotes. */
  private static List<String> split(final String items) {
    final List<String> res = new ArrayList<>();
    final StringBuilder buf = new StringBuilder();
    char quote = 0;
    for (int i = 0; i < items.length(); i++) {
      final char c = items.charAt(i);
      if (quote != 0) {
        buf.append(c);
        if (c == '\\' && quote == '"' && i + 1 < items.length()) {
          buf.append(items.charAt(++i));
        } else if (c == quote) {
          quote = 0;
        }
      } else if (c == '"' || c == '\'') {
        quote = c;
        buf.append(c);
      } else if (c == ',') {
        res.add(buf.toString().trim());
        buf.setLength(0);
      } else {
        buf.append(c);
      }
    }
    if (buf.toString().trim().length() > 0 || !res.isEmpty()) {
      res.add(buf.toString().trim());
    }
    return res;
  }

  private static String unquote(final String value) {
    final String v = value.trim();
    if (v.length() >= 2 && v.startsWith("\"") && v.endsWith("\"")) {
      final StringBuilder buf = new StringBuilder();
      for (int i = 1; i < v.length() - 1; i++) {
        final char c = v.charAt(i);
        if (c == '\\' && i + 1 < v.length() - 1) {
          final char n = v.charAt(++i);
          buf.append(n == 'n' ? '\n' : n == 't' ? '\t' : n);
        } else {
          buf.append(c);
        }
      }
      return buf.toString();
    }
    if (v.length() >= 2 && v.startsWith("'") && v.endsWith("'")) {
      return v.substring(1, v.length() - 1).replace("''", "'");
    }
    return v;
  }
}
