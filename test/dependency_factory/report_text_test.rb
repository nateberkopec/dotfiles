require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryReportTextTest < Minitest::Test
  def test_plain_report_text_is_unchanged
    assert_equal "No updates.", DependencyFactory::ReportText.publishable("No updates.")
  end

  def test_scoped_urls_survive_repeated_safe_output_processing
    url = "https://www.npmjs.com/package/%40narumitw/pi-btw/v/0.60.0"
    (0..3).each do |count|
      ticks = "`" * count
      text = "| pi:#{ticks}@narumitw/pi-btw#{ticks} | [0.60.0](https://www.npmjs.com/package/#{ticks}@narumitw/pi-btw#{ticks}/v/0.60.0) |"
      expected = "| pi:#{ticks}@narumitw/pi-btw#{ticks} | [0.60.0](#{url}) |"
      assert_equal expected, DependencyFactory::ReportText.publishable(text)
      assert_equal expected, DependencyFactory::ReportText.publishable(expected)
    end
  end

  def test_only_mention_wrappers_are_removed_from_quotes
    text = "The `parser` fixes the bug reported by (@reporter)."
    assert_equal text, DependencyFactory::ReportText.unescape_mentions(text)
    assert_equal text, DependencyFactory::ReportText.unescape_mentions(text.sub("@reporter", "``@reporter``"))
  end

  def test_unrelated_backticks_in_urls_are_not_repaired
    text = "[notes](https://example.test/`invalid`/notes)"
    assert_equal text, DependencyFactory::ReportText.publishable(text)
    assert_empty DependencyFactory::Report.urls(text)
  end

  def test_canonical_urls_compare_encoded_scopes_with_source_urls
    url = "https://www.npmjs.com/package/@narumitw/pi-btw/v/0.60.0"
    assert_equal url, DependencyFactory::ReportText.canonical_url(url)
    assert_equal url, DependencyFactory::ReportText.canonical_url(url.sub("@", "%40"))
  end
end
