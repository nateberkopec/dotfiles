require_relative "../test_helper"
require_relative "../../files/home/.claude/skills/readability/scripts/markdown_prose"
require_relative "../../files/home/.claude/skills/readability/scripts/flesch_kincaid"

class ReadabilityAuditTest < Minitest::Test
  def test_markdown_boundaries_and_code_exclusion
    markdown = <<~MD
      # Unpunctuated heading words do not count

      Opening block without punctuation

      - First bullet without punctuation
      - Second bullet without punctuation

      ```ruby
      secret code words. Another sentence.
      ```

      Ordinary prose has two sentences. This is the second!
    MD

    assert_equal 5, MarkdownProse.sentences(markdown).size
    assert_equal ["Opening block without punctuation", "First bullet without punctuation",
      "Second bullet without punctuation"], MarkdownProse.blocks(markdown).first(3)
    refute_includes MarkdownProse.words(markdown), "secret"
    refute_includes MarkdownProse.words(markdown), "heading"
  end

  def test_structural_text_excludes_fenced_and_indented_code
    markdown = "```markdown\n# Fake heading\n- Fake item\n```\n# Real heading\n\t# Tab-indented code\n"

    structure = MarkdownProse.structural_text(markdown)

    assert_includes structure, "# Real heading"
    refute_includes structure, "Fake heading"
    refute_includes structure, "Tab-indented"
  end

  def test_grade_calculator_uses_markdown_sentence_boundaries
    markdown = "# Heading words\n\nOne short block\n\n- Another short block\n"

    grade = FleschKincaidCalculator.new.grade_level(markdown)

    assert_in_delta(1.31, grade, 0.1)
    assert_equal 2, MarkdownProse.sentences(markdown).size
  end
end
