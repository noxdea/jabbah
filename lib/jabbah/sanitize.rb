# frozen_string_literal: true

require "uri"

module Jabbah
  module Sanitize
    DROP_ELEMENTS = %w[base embed form iframe link object script style].freeze
    PROFILES = {
      docs: {allow_style: false, allow_remote_images: false},
      feed: {allow_style: false, allow_remote_images: false},
      mail: {allow_style: false, allow_remote_images: false}
    }.freeze
    DEFAULT = PROFILES[:docs]
    SAFE_ELEMENTS = %w[a abbr article aside b blockquote body br caption cite code col colgroup dd del details div dl dt em figcaption figure h1 h2 h3 h4 h5 h6 head header hr html i img ins kbd li main mark meta nav ol p pre q rp rt ruby s samp section small span strong sub summary sup table tbody td tfoot th thead time title tr u ul var].freeze
    GLOBAL_ATTRIBUTES = %w[aria-label aria-describedby aria-hidden class dir id lang role title].freeze
    URL_ATTRIBUTES = %w[href src cite action poster].freeze

    module_function

    def clean(document, profile: :docs, allow: DEFAULT, base_url: nil, on_blocked: nil)
      source = document.is_a?(Document) ? document.clone : Document.parse(document)
      options = profile.is_a?(Hash) ? profile : PROFILES.fetch(profile.to_sym) { DEFAULT }
      allowed = allow.is_a?(Hash) ? allow : DEFAULT
      blocked = 0
      walk = lambda do |node|
        node.children.dup.each do |child|
          if child.element?
            if DROP_ELEMENTS.include?(child.name) || !SAFE_ELEMENTS.include?(child.name)
              child.remove
              next
            end
            if child.name == "meta" && child["http-equiv"].to_s.casecmp("refresh").zero?
              child.remove
              next
            end
            sanitize_attributes(child, options, allowed, base_url) do |url|
              blocked += 1
              on_blocked&.call(url)
            end
            walk.call(child)
          elsif child.comment?
            child.remove
          end
        end
      end
      walk.call(source.instance_variable_get(:@tree))
      source.mark_blocked!(blocked)
    end

    def sanitize_attributes(node, options, allowed, base_url)
      node.attributes.keys.each do |name|
        value = node[name]
        unless attribute_allowed?(name, node.name, allowed)
          node.attributes.delete(name)
          next
        end
        if name.start_with?("on") || name == "style"
          node.attributes.delete(name)
          next
        end
        if URL_ATTRIBUTES.include?(name)
          url = clean_url(value, base_url: base_url, attribute: name, node: node,
            allow_remote_images: options[:allow_remote_images])
          if url == :blocked_image
            original = value.to_s
            node.attributes.delete(name)
            node["data-blocked-src"] = original
            yield original
          elsif url == :invalid
            node.attributes.delete(name)
          else
            node[name] = url
          end
        end
      end
      if node.name == "a" && node["href"]
        node["target"] = "_blank"
        rel = node["rel"].to_s.split
        node["rel"] = (rel + %w[noopener noreferrer]).uniq.join(" ")
      end
    end

    def attribute_allowed?(name, _element, allowed)
      return true if GLOBAL_ATTRIBUTES.include?(name) || name.start_with?("aria-") || name.start_with?("data-")
      return true if allowed.is_a?(Hash) && allowed[name]

      %w[alt charset content height href http-equiv id media name rel role src target type width].include?(name)
    end

    def clean_url(value, base_url:, attribute:, node:, allow_remote_images: false)
      original = value.to_s.strip.gsub(/[\x00-\x20]/, "")
      return :invalid if original.empty?
      downcased = original.downcase
      if downcased.start_with?("data:")
        return :invalid unless node.name == "img" && original.match?(/\Adata:image\/(?:png|gif|jpe?g|webp);base64,[a-z0-9+\/=]+\z/i)
        return original
      end
      return :invalid if downcased.start_with?("javascript:", "vbscript:", "file:")
      return :invalid if attribute != "src" && downcased.start_with?("cid:")
      return original if downcased.start_with?("cid:")

      if node.name == "img" && !allow_remote_images && downcased.match?(%r{\A(?:https?:)?//})
        return :blocked_image
      end
      return original unless base_url

      URI.join(base_url.to_s, original).to_s
    rescue URI::InvalidURIError
      :invalid
    end
  end
end
