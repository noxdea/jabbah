# frozen_string_literal: true

module Jabbah
  module Extract
    module_function

    POSITIVE = /article|content|entry|main|page|post|story|text|body/i
    NEGATIVE = /ad|advert|comment|footer|header|nav|promo|related|share|sidebar|social|sponsor/i

    def article(document)
      doc = document.is_a?(Document) ? document : Document.parse(document)
      candidates = doc.search("article, main, section, div, td")
      scored = candidates.filter_map do |node|
        score = score_node(node)
        [score, node] if score >= 1
      end
      best = scored.max_by(&:first)&.last
      return nil unless best

      title = doc.title || doc.at("h1")&.text&.strip
      byline_node = doc.search("[class], [id]").find { |node| node["class"].to_s.match?(/author|byline/i) || node["id"].to_s.match?(/author|byline/i) }
      excerpt = normalize(best.text)[0, 240]
      {title: title, byline: byline_node&.text&.strip, content: best, excerpt: excerpt}
    end

    def score_node(node)
      text = normalize(node.text)
      return -100 if text.length < 40

      paragraphs = node.descendants.count { |child| child.element? && %w[p pre].include?(child.name) }
      return -100 if paragraphs.zero? && node.name == "div"

      links = node.search("a").sum { |link| normalize(link.text).length }
      density = text.length - [links * 2, text.length].min
      classes = "#{node["id"]} #{node["class"]}"
      score = (density / 100.0) + (paragraphs * 3)
      score += 25 if classes.match?(POSITIVE)
      score -= 35 if classes.match?(NEGATIVE)
      score
    end

    def normalize(text)
      text.to_s.gsub(/\s+/, " ").strip
    end
  end
end
