package com.elovirta.dita.markdown.verify;

import java.io.File;
import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import org.dita.dost.exception.DITAOTException;
import org.dita.dost.module.AbstractPipelineModuleImpl;
import org.dita.dost.pipeline.AbstractPipelineInput;
import org.dita.dost.pipeline.AbstractPipelineOutput;
import org.dita.dost.util.Job;

/**
 * Build step for the <code>markdown_lossless</code> transtype. Runs {@link LosslessCheck}
 * on every topic of the job against the file generated for it, writes a
 * report, and fails the build when source text is missing.
 *
 * <p>The source side is the topic in the temporary directory, after conrefs
 * and keys are resolved and filtering is applied. Text of the authored file
 * that did not survive preprocessing is listed separately: with a DITAVAL
 * file that is expected, without one it points at a conref or key that did
 * not resolve. The <code>source</code> parameter makes that list fail the
 * build as well.</p>
 */
public class LosslessCheckModule extends AbstractPipelineModuleImpl {

  @Override
  public AbstractPipelineOutput execute(final AbstractPipelineInput input) throws DITAOTException {
    final File outputDir = new File(input.getAttribute("output.dir"));
    final String ext = input.getAttribute("out.ext") != null ? input.getAttribute("out.ext") : ".md";
    final boolean fail = !"no".equals(input.getAttribute("fail")) && !"false".equals(input.getAttribute("fail"));
    final String reportFile = input.getAttribute("report");
    final String sourceMode = input.getAttribute("source") != null ? input.getAttribute("source") : "report";

    final List<LosslessCheck.Result> results = new ArrayList<>();
    for (Job.FileInfo fi : job.getFileInfo(f -> "dita".equals(f.format) && !f.isResourceOnly)) {
      final File source = new File(job.tempDir, fi.file.getPath());
      if (!source.isFile()) {
        continue;
      }
      final File authored = "no".equals(sourceMode) || fi.src == null || !"file".equals(fi.src.getScheme())
        ? null
        : new File(fi.src.getPath());
      results.add(LosslessCheck.check(source, new File(outputDir, resultPath(fi, ext)), authored));
    }

    final String report = LosslessCheck.report(results);
    final String removed = LosslessCheck.reportRemoved(results);
    final long failed = results.stream().filter(r -> !r.passed()).count();
    final long compared = results.stream().mapToLong(r -> r.checked).sum();
    final long removedCount = results.stream().mapToLong(r -> r.removedBefore.size()).sum();
    final String summary =
      results.size() +
      " topics and " +
      compared +
      " pieces of text compared, " +
      failed +
      " topics with missing text, " +
      removedCount +
      " pieces removed by preprocessing";
    if (reportFile != null) {
      try {
        Files.write(
          new File(reportFile).toPath(),
          (report + removed + summary + "\n").getBytes(StandardCharsets.UTF_8)
        );
      } catch (IOException e) {
        logger.warn("Cannot write " + reportFile + ": " + e.getMessage());
      }
    }
    final boolean failOnRemoved = "fail".equals(sourceMode) && removedCount > 0;
    for (String line : removed.split("\n")) {
      if (!line.isEmpty()) {
        if (failOnRemoved) {
          logger.error(line);
        } else {
          logger.warn(line);
        }
      }
    }
    if (failed == 0 && !failOnRemoved) {
      logger.info("Markdown output verified: " + summary);
      return null;
    }
    for (String line : report.split("\n")) {
      if (!line.isEmpty()) {
        logger.error(line);
      }
    }
    if (failOnRemoved || (fail && failed > 0)) {
      throw new DITAOTException("Markdown output is missing source text: " + summary);
    }
    logger.warn(summary);
    return null;
  }

  /** Same mapping as the transform uses: result path relative to the input directory, new extension. */
  private String resultPath(final Job.FileInfo fi, final String ext) {
    final String path;
    if (fi.result == null) {
      path = fi.file.getPath();
    } else {
      final URI rel = job.getInputDir().relativize(fi.result);
      path = rel.isAbsolute() ? fi.file.getPath() : rel.getPath();
    }
    final int dot = path.lastIndexOf('.');
    final int slash = Math.max(path.lastIndexOf('/'), path.lastIndexOf(File.separatorChar));
    return (dot > slash ? path.substring(0, dot) : path) + ext;
  }
}
