package com.elovirta.dita.html;

import com.elovirta.dita.utils.AbstractReaderTest;
import com.vladsch.flexmark.util.data.DataSet;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.xml.sax.XMLReader;

public class HtmlReaderTest extends AbstractReaderTest {

  private XMLReader r = new HtmlReader(new DataSet(), "html2dita.xsl");

  @Override
  public XMLReader getReader() {
    return r;
  }

  @Override
  public String getSrc() {
    return "html/";
  }

  @Override
  public String getExp() {
    return "dita/";
  }

  @ParameterizedTest
  @ValueSource(
    strings = {
      "body_attributes.html",
      "codeblock.html",
      "comment.html",
      "concept.html",
      "conkeyref.html",
      "conref.html",
      "dl.html",
      "entity.html",
      "escape.html",
      "hdita.html",
      "header.html",
      "header_attributes.html",
      "html.html",
      "image-size.html",
      "image.html",
      "inline.html",
      "inline_extended.html",
      "keyref.html",
      "keys.html",
      "linebreak.html",
      "link.html",
      "multiple_top_level_specialized.html",
      "ol.html",
      "quote.html",
      "reference.html",
      "short.html",
      "shortdesc.html",
      "table-width.html",
      "table.html",
      "task.html",
      "task/task_choices.html",
      "task/task_choicetable.html",
      "task/task_substeps.html",
      "taskOneStep.html",
      "ul.html",
      //            "multiple_top_level.html",
      //            "pandoc_header.html",
      //            "topic.html",
      //            "yaml.html",
    }
  )
  public void test(String file) throws Exception {
    run(file);
  }

  @ParameterizedTest
  @CsvSource(
    {
      "task/task_choices_implicit.html,task/task_choices.dita",
      "task/task_choicetable_implicit.html,task/task_choicetable.dita",
      "task/task_substeps_implicit.html,task/task_substeps.dita",
    }
  )
  public void testImplicit(String src, String exp) throws Exception {
    r.setFeature("http://lwdita.org/sax/features/implicit-choices", true);
    r.setFeature("http://lwdita.org/sax/features/implicit-choicetable", true);
    r.setFeature("http://lwdita.org/sax/features/implicit-substeps", true);

    run(getSrc() + src, getExp() + exp);
  }
}
