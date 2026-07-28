package com.elovirta.dita.markdown;

import static com.elovirta.dita.markdown.renderer.TopicRenderer.TIGHT_LIST_P;
import static javax.xml.XMLConstants.NULL_NS_URI;
import static org.dita.dost.util.Constants.*;

import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.dita.dost.util.Constants;
import org.dita.dost.util.DitaClass;
import org.xml.sax.Attributes;
import org.xml.sax.SAXException;
import org.xml.sax.helpers.AttributesImpl;
import org.xml.sax.helpers.XMLFilterImpl;

public class SpecializeFilter extends XMLFilterImpl {

  private static final int DEPTH_IN_BODY = 3;

  public enum Type {
    TOPIC,
    CONCEPT,
    TASK,
    REFERENCE,
  }

  private enum ReferenceState {
    BODY,
    SECTION,
  }

  private enum TaskState {
    BODY,
    CONTEXT,
    STEPS,
    STEP,
    INFO,
    SUBSTEPS,
    SUBSTEP,
    SUBINFO,
    RESULT,
    POST_STEPS,
  }

  private final Type forceType;

  /**
   * Topic type stack. Default to topic in case of compound type
   */
  private final Deque<Type> typeStack = new ArrayDeque<>(List.of(Type.TOPIC));
  private int paragraphCountInStep = 0;
  private int paragraphCountInSubstep = 0;
  private int depth = 0;
  private TaskState taskState = null;
  private ReferenceState referenceState = null;

  private static final Map<String, DitaClass> TASK_SECTIONS = Map.of(
    TASK_PREREQ.localName,
    TASK_PREREQ,
    TASK_CONTEXT.localName,
    TASK_CONTEXT,
    TASK_RESULT.localName,
    TASK_RESULT,
    TASK_POSTREQ.localName,
    TASK_POSTREQ,
    TASK_TASKTROUBLESHOOTING.localName,
    TASK_TASKTROUBLESHOOTING
  );

  private final Deque<String> elementStack = new ArrayDeque<>();

  public SpecializeFilter() {
    this(null);
  }

  public SpecializeFilter(Type forceType) {
    super();
    this.forceType = forceType;
  }

  @Override
  public void startElement(String uri, String localName, String qName, Attributes atts) throws SAXException {
    depth++;

    if (localName.equals(TOPIC_TOPIC.localName)) {
      depth = 1;
      if (forceType != null) {
        typeStack.push(forceType);
      } else {
        final Collection<String> outputclasses = getOutputclass(atts);
        if (outputclasses.contains(CONCEPT_CONCEPT.localName)) {
          typeStack.push(Type.CONCEPT);
        } else if (outputclasses.contains(TASK_TASK.localName)) {
          typeStack.push(Type.TASK);
        } else if (outputclasses.contains(REFERENCE_REFERENCE.localName)) {
          typeStack.push(Type.REFERENCE);
        } else {
          typeStack.push(typeStack.peek());
        }
      }
    }

    switch (typeStack.peek()) {
      case CONCEPT:
        startElementConcept(uri, localName, qName, atts);
        break;
      case TASK:
        startElementTask(uri, localName, qName, atts);
        break;
      case REFERENCE:
        startElementReference(uri, localName, qName, atts);
        break;
      default:
        doStartElement(uri, localName, qName, atts);
    }
  }

  @Override
  public void endElement(String uri, String localName, String qName) throws SAXException {
    switch (typeStack.peek()) {
      case TASK:
        endElementTask(uri, localName, qName);
        break;
      case REFERENCE:
        endElementReference(uri, localName, qName);
        break;
      case CONCEPT:
        endElementConcept(uri, localName, qName);
        break;
      default:
        doEndElement(uri, localName, qName);
    }

    if (localName.equals(TOPIC_TOPIC.localName)) {
      typeStack.pop();
    }

    depth--;
  }

  private void startElementConcept(String uri, String localName, String qName, Attributes atts) throws SAXException {
    switch (localName) {
      case "topic":
        renameStartElement(Constants.CONCEPT_CONCEPT, atts);
        break;
      case "body":
        renameStartElement(Constants.CONCEPT_CONBODY, atts);
        break;
      default:
        doStartElement(uri, localName, qName, atts);
    }
  }

  private void endElementConcept(String uri, String localName, String qName) throws SAXException {
    doEndElement(uri, localName, qName);
  }

  private void startElementTask(String uri, String localName, String qName, Attributes atts) throws SAXException {
    switch (localName) {
      case "topic":
        renameStartElement(TASK_TASK, atts);
        taskState = null;
        break;
      case "body":
        taskState = TaskState.BODY;
        paragraphCountInSubstep = 0;
        renameStartElement(TASK_TASKBODY, atts);
        break;
      case "section":
        if (depth == DEPTH_IN_BODY) {
          closeImplicitSection();
          final String outputclass = atts.getValue(ATTRIBUTE_NAME_OUTPUTCLASS);
          if (outputclass != null) {
            final DitaClass sectionClass = TASK_SECTIONS.get(outputclass.trim());
            if (sectionClass != null) {
              renameStartElement(sectionClass, atts);
              break;
            }
          }
          openImplicitSection();
          doStartElement(uri, localName, qName, atts);
        } else {
          doStartElement(uri, localName, qName, atts);
        }
        break;
      case "ol":
        if (depth == DEPTH_IN_BODY) {
          closeImplicitSection();
          taskState = TaskState.STEPS;
          renameStartElement(Constants.TASK_STEPS, atts);
        } else if (depth == 5 && (taskState == TaskState.STEP || taskState == TaskState.INFO)) {
          if (taskState == TaskState.INFO) {
            doEndElement(TASK_INFO);
          }
          taskState = TaskState.SUBSTEPS;
          renameStartElement(TASK_SUBSTEPS, atts);
        } else {
          doStartElement(uri, localName, qName, atts);
        }
        break;
      case "ul":
        if (depth == DEPTH_IN_BODY) {
          closeImplicitSection();
          taskState = TaskState.STEPS;
          renameStartElement(TASK_STEPS_UNORDERED, atts);
        } else {
          doStartElement(uri, localName, qName, atts);
        }
        break;
      case "li":
        if (taskState == TaskState.STEPS && depth == 4) {
          renameStartElement(TASK_STEP, atts);
          taskState = TaskState.STEP;
        } else if (taskState == TaskState.SUBSTEPS && depth == 6) {
          renameStartElement(TASK_SUBSTEP, atts);
          taskState = TaskState.SUBSTEP;
        } else {
          doStartElement(uri, localName, qName, atts);
        }
        break;
      default:
        if (depth == DEPTH_IN_BODY) {
          if (taskState == TaskState.BODY) {
            doStartElement(TASK_CONTEXT);
            taskState = TaskState.CONTEXT;
          }
          openImplicitSection();
          doStartElement(uri, localName, qName, atts);
        } else if ((taskState == TaskState.STEP || taskState == TaskState.INFO) && depth == 5) {
          switch (localName) {
            case "p":
            case TIGHT_LIST_P:
              paragraphCountInStep++;
              if (paragraphCountInStep == 1) {
                renameStartElement(TASK_CMD, atts);
              } else if (paragraphCountInStep == 2 && taskState != TaskState.INFO) {
                doStartElement(TASK_INFO);
                taskState = TaskState.INFO;
                doStartElement(uri, localName, qName, atts);
              } else {
                doStartElement(uri, localName, qName, atts);
              }
              break;
            default:
              if (taskState != TaskState.INFO) {
                doStartElement(TASK_INFO);
                taskState = TaskState.INFO;
              }
              doStartElement(uri, localName, qName, atts);
              break;
          }
        } else if ((taskState == TaskState.SUBSTEP || taskState == TaskState.SUBINFO) && depth == 7) {
          switch (localName) {
            case "p":
            case TIGHT_LIST_P:
              paragraphCountInSubstep++;
              if (paragraphCountInSubstep == 1) {
                renameStartElement(TASK_CMD, atts);
              } else if (paragraphCountInSubstep == 2 && taskState != TaskState.SUBINFO) {
                AttributesImpl res = createAttributes(TASK_INFO);
                doStartElement(NULL_NS_URI, TASK_INFO.localName, TASK_INFO.localName, res);
                taskState = TaskState.SUBINFO;
                doStartElement(uri, localName, qName, atts);
              } else {
                doStartElement(uri, localName, qName, atts);
              }
              break;
            default:
              if (taskState != TaskState.SUBINFO) {
                AttributesImpl res = createAttributes(TASK_INFO);
                doStartElement(NULL_NS_URI, TASK_INFO.localName, TASK_INFO.localName, res);
                taskState = TaskState.SUBINFO;
              }
              doStartElement(uri, localName, qName, atts);
              break;
          }
        } else {
          doStartElement(uri, localName, qName, atts);
        }
    }
  }

  private void closeImplicitSection() throws SAXException {
    if (taskState == TaskState.CONTEXT) {
      doEndElement(TASK_CONTEXT);
      taskState = TaskState.BODY;
    } else if (taskState == TaskState.RESULT) {
      doEndElement(TASK_RESULT);
      taskState = TaskState.POST_STEPS;
    }
  }

  private void openImplicitSection() throws SAXException {
    if (taskState == TaskState.BODY) {
      doStartElement(TASK_CONTEXT);
      taskState = TaskState.CONTEXT;
    } else if (taskState == TaskState.POST_STEPS) {
      doStartElement(TASK_RESULT);
      taskState = TaskState.RESULT;
    }
  }

  private void endElementTask(String uri, String localName, String qName) throws SAXException {
    switch (localName) {
      case "body":
        if (taskState == TaskState.CONTEXT) {
          taskState = null;
          doEndElement(uri, TASK_CONTEXT.localName, TASK_CONTEXT.localName);
        } else if (taskState == TaskState.RESULT) {
          taskState = null;
          doEndElement(uri, TASK_RESULT.localName, TASK_RESULT.localName);
        }
        doEndElement(uri, localName, qName);
        break;
      case "ol":
        if (depth == DEPTH_IN_BODY) {
          taskState = TaskState.POST_STEPS;
        } else if (depth == 5 && taskState == TaskState.SUBSTEPS) {
          taskState = TaskState.STEP;
        }
        doEndElement(uri, localName, qName);
        break;
      case "ul":
        if (depth == DEPTH_IN_BODY) {
          taskState = TaskState.STEP;
        }
        doEndElement(uri, localName, qName);
        break;
      case "li":
        if (taskState == TaskState.SUBINFO && depth == 6) {
          doEndElement(TASK_INFO);
          taskState = TaskState.SUBSTEP;
        }
        if (taskState == TaskState.SUBSTEP && depth == 6) {
          paragraphCountInSubstep = 0;
          taskState = TaskState.SUBSTEPS;
        }
        if (taskState == TaskState.INFO && depth == 4) {
          doEndElement(TASK_INFO);
          taskState = TaskState.STEP;
        }
        if (taskState == TaskState.STEP && depth == 4) {
          paragraphCountInStep = 0;
          taskState = TaskState.STEPS;
        }
        doEndElement(uri, localName, qName);
        break;
      default:
        doEndElement(uri, localName, qName);
    }
  }

  private void startElementReference(String uri, String localName, String qName, Attributes atts) throws SAXException {
    switch (localName) {
      case "topic":
        referenceState = null;
        renameStartElement(REFERENCE_REFERENCE, atts);
        break;
      case "body":
        renameStartElement(REFERENCE_REFBODY, atts);
        referenceState = ReferenceState.BODY;
        break;
      default:
        if (depth == DEPTH_IN_BODY) {
          switch (localName) {
            case "table":
            case "section":
              if (referenceState == ReferenceState.SECTION) {
                referenceState = ReferenceState.BODY;
                doEndElement(TOPIC_SECTION);
              }
              break;
            default:
              if (referenceState == ReferenceState.BODY) {
                doStartElement(TOPIC_SECTION);
                referenceState = ReferenceState.SECTION;
              }
              break;
          }
          doStartElement(uri, localName, qName, atts);
        } else {
          doStartElement(uri, localName, qName, atts);
        }
    }
  }

  private void endElementReference(String uri, String localName, String qName) throws SAXException {
    switch (localName) {
      case "body":
        if (referenceState == ReferenceState.SECTION) {
          referenceState = null;
          doEndElement(TOPIC_SECTION);
        }
        doEndElement(uri, localName, qName);
        break;
      default:
        doEndElement(uri, localName, qName);
    }
  }

  public void doStartElement(String uri, String localName, String qName, Attributes atts) throws SAXException {
    //        System.out.printf("<%s>%n", localName);
    super.startElement(uri, localName, qName, atts);
    elementStack.push(localName);
  }

  private void doStartElement(DitaClass cls) throws SAXException {
    AttributesImpl res = createAttributes(cls);
    doStartElement(NULL_NS_URI, cls.localName, cls.localName, res);
  }

  public void doEndElement(String uri, String localName, String qName) throws SAXException {
    final String l = elementStack.pop();
    //        System.out.printf("</%s = %s>%n", l, localName);
    super.endElement(uri, l, l);
  }

  private void doEndElement(DitaClass cls) throws SAXException {
    doEndElement(NULL_NS_URI, cls.localName, cls.localName);
  }

  void renameStartElement(DitaClass cls, Attributes atts) throws SAXException {
    AttributesImpl res = new AttributesImpl(atts);
    final int classIndex = res.getIndex(ATTRIBUTE_NAME_CLASS);
    if (classIndex != -1) {
      res.setValue(classIndex, cls.toString());
    } else {
      res.addAttribute(NULL_NS_URI, ATTRIBUTE_NAME_CLASS, ATTRIBUTE_NAME_CLASS, "CDATA", cls.toString());
    }
    final int outputClassIndex = res.getIndex(NULL_NS_URI, ATTRIBUTE_NAME_OUTPUTCLASS);
    if (outputClassIndex != -1) {
      final String outputClassValue = res.getValue(outputClassIndex).trim();
      if (outputClassValue.isEmpty()) {
        res.removeAttribute(outputClassIndex);
      } else {
        final List<String> outputClass = Stream
          .of(outputClassValue.split("\\s+"))
          .filter(token -> !token.equals(cls.localName))
          .collect(Collectors.toList());
        if (outputClass.isEmpty()) {
          res.removeAttribute(outputClassIndex);
        } else {
          res.setValue(outputClassIndex, String.join(" ", outputClass));
        }
      }
    }
    doStartElement(NULL_NS_URI, cls.localName, cls.localName, res);
  }

  private Collection<String> getOutputclass(Attributes atts) {
    final String outputclass = atts.getValue(ATTRIBUTE_NAME_OUTPUTCLASS);
    if (outputclass == null) {
      return Collections.emptyList();
    }
    return Arrays.asList(outputclass.trim().split("\\s+"));
  }

  private AttributesImpl createAttributes(DitaClass cls) {
    AttributesImpl res = new AttributesImpl();
    res.addAttribute(NULL_NS_URI, ATTRIBUTE_NAME_CLASS, ATTRIBUTE_NAME_CLASS, "CDATA", cls.toString());
    return res;
  }
}
