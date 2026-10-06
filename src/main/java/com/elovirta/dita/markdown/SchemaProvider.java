package com.elovirta.dita.markdown;

import com.vladsch.flexmark.util.data.DataSet;
import java.net.URI;

/**
 * Markdown schema provider for parsers.
 */
public interface SchemaProvider {
  /**
   * Test whether schema is supported by this provider.
   *
   * @param schema Markdown schema
   */
  boolean isSupportedSchema(URI schema);

  /**
   * Create Markdown parser for schema.
   *
   * @param schema Markdown schema
   * @return parser for schema
   */
  MarkdownParser createMarkdownParser(URI schema);

  /**
   * Create Markdown parser for schema, honouring options the caller set on the reader.
   *
   * <p>Implementations that build their options from scratch should layer {@code overrides}
   * on top, so a feature configured on the reader is not lost for documents that declare a
   * schema. The default implementation ignores them, which keeps existing providers working.
   *
   * @param schema Markdown schema
   * @param overrides options set explicitly on the reader, to apply over the schema's own
   * @return parser for schema
   */
  default MarkdownParser createMarkdownParser(URI schema, DataSet overrides) {
    return createMarkdownParser(schema);
  }
}
