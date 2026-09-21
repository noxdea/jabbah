# frozen_string_literal: true

module Jabbah
  class Document
    attr_reader :encoding, :blocked_count

    def self.parse(input, encoding: :auto)
      text, detected = EncodingSupport.decode(input, encoding)
      document = Parser.new(text, fragment: false).parse
      document.instance_variable_set(:@encoding, detected)
      document
    end

    def self.fragment(input, context: "div")
      text, detected = EncodingSupport.decode(input, :auto)
      document = Parser.new(text, fragment: true, context: context).parse
      document.instance_variable_set(:@encoding, detected)
      document
    end

    def initialize(tree, encoding: Encoding::UTF_8)
      @tree = tree
      @encoding = encoding
      @blocked_count = 0
    end

    def root
      @tree.children.find(&:element?) || @tree
    end

    def children = @tree.children
    def head = root.element? ? root.children.find { |node| node.element? && node.name == "head" } : nil
    def body = root.element? ? root.children.find { |node| node.element? && node.name == "body" } : nil
    def title = search("title").first&.text&.strip
    def doctype = @tree.children.find { |node| node.type == :doctype }&.data
    def text = @tree.text

    def at(selector)
      search(selector).first
    end

    def search(selector)
      Selector.search(@tree, selector)
    end

    def each(&block) = @tree.each(&block)
    def to_html(indent: nil) = @tree.to_html(indent: indent)
    def clone = Document.new(@tree.clone, encoding: encoding)

    def mark_blocked!(count)
      @blocked_count = count
      self
    end
  end

  module EncodingSupport
    module_function

    def decode(input, requested)
      bytes = input.to_s.dup
      bytes.force_encoding(Encoding::BINARY)
      if requested != :auto
        encoding = Encoding.find(requested.to_s)
        return [bytes.force_encoding(encoding).encode(Encoding::UTF_8, invalid: :replace, undef: :replace), encoding]
      end

      if bytes.start_with?("\xEF\xBB\xBF".b)
        return [bytes.byteslice(3..).force_encoding(Encoding::UTF_8).scrub, Encoding::UTF_8]
      end
      if bytes.start_with?("\xFF\xFE".b)
        return [bytes.byteslice(2..).force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8, invalid: :replace), Encoding::UTF_16LE]
      end
      if bytes.start_with?("\xFE\xFF".b)
        return [bytes.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8, invalid: :replace), Encoding::UTF_16BE]
      end

      ascii = bytes.byteslice(0, 4096).to_s.force_encoding(Encoding::ASCII_8BIT)
      declared = ascii[/<meta[^>]+charset\s*=\s*["']?\s*([A-Za-z0-9._-]+)/i, 1]
      if declared
        begin
          encoding = Encoding.find(declared)
          return [bytes.force_encoding(encoding).encode(Encoding::UTF_8, invalid: :replace, undef: :replace), encoding]
        rescue ArgumentError
          # Fall through to UTF-8 for unknown declarations.
        end
      end
      [bytes.force_encoding(Encoding::UTF_8).scrub, Encoding::UTF_8]
    end
  end
end
