# frozen_string_literal: true

require_relative "test_helper"

class JabbahTest < Minitest::Test
  def test_recovers_malformed_html_and_serializes_escaped_text
    document = Jabbah.parse('<p>one <b>two<p>three &amp; four')

    assert_equal "html", document.root.name
    assert_equal 2, document.search("p").length
    assert_equal "one two", document.search("p").first.text
    assert_includes document.to_html, "three &amp; four"
  end

  def test_fragment_does_not_add_html_wrappers
    document = Jabbah.fragment("<li>A</li><li>B</li>")

    assert_equal "li", document.root.name
    assert_equal 2, document.search("li").length
  end

  def test_selectors_support_descendants_attributes_and_pseudos
    document = Jabbah.parse('<main><p class="lead" data-kind="x">A</p><p>B</p></main>')

    assert_equal 1, document.search("main > p.lead[data-kind='x']:first-child").length
    assert_equal 1, document.search("p:last-child").length
    assert_equal 2, document.search("main p").length
  end

  def test_encoding_uses_meta_charset
    bytes = "<meta charset='ISO-8859-1'><p>caf\xE9</p>".b
    document = Jabbah.parse(bytes)

    assert_equal Encoding::ISO_8859_1, document.encoding
    assert_equal "café", document.at("p").text
  end

  def test_sanitizer_removes_xss_and_reports_remote_images
    blocked = []
    input = '<script>alert(1)</script><p onclick="alert(1)"><img src="https://tracker.test/p.gif"><a href="javascript:alert(1)">link</a></p>'
    document = Jabbah::Sanitize.clean(input, on_blocked: ->(url) { blocked << url })

    refute_includes document.to_html.downcase, "script"
    refute_includes document.to_html.downcase, "onclick"
    refute_includes document.to_html.downcase, "javascript"
    assert_includes document.to_html, 'data-blocked-src="https://tracker.test/p.gif"'
    assert_equal ["https://tracker.test/p.gif"], blocked
    assert_equal 1, document.blocked_count
  end

  def test_sanitizer_preserves_cid_and_absolutizes_links
    document = Jabbah::Sanitize.clean('<img src="cid:logo"><a href="/guide">guide</a>', base_url: "https://example.test/docs/")

    assert_equal "cid:logo", document.at("img")["src"]
    assert_equal "https://example.test/guide", document.at("a")["href"]
    assert_equal "_blank", document.at("a")["target"]
    assert_equal "noopener noreferrer", document.at("a")["rel"]
  end

  def test_article_extraction_prefers_content_over_sidebar
    html = <<~HTML
      <html><head><title>Article title</title></head><body>
        <aside class="sidebar">#{"ad " * 100}</aside>
        <article class="article-content"><p>#{"Useful article text. " * 30}</p></article>
      </body></html>
    HTML

    result = Jabbah::Extract.article(html)

    refute_nil result
    assert_equal "Article title", result[:title]
    assert_equal "article", result[:content].name
    assert_includes result[:excerpt], "Useful article text"
  end
end
