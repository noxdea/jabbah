# frozen_string_literal: true

require "cgi/escape"

module Jabbah
  class Parser
    BLOCK_ELEMENTS = %w[address article aside blockquote div dl fieldset footer form h1 h2 h3 h4 h5 h6 header hr main nav ol p pre section table ul].freeze
    RAW_ELEMENTS = %w[script style].freeze

    def initialize(source, fragment:, context: "div")
      @source = source.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      @fragment = fragment
      @context = context.to_s.downcase
      @document = Node.new(:document)
      @stack = [@document]
      @index = 0
    end

    def parse
      scan
      normalize_document unless @fragment
      Document.new(@document)
    end

    private

    def scan
      while @index < @source.length
        if @source[@index] != "<"
          add_text(read_text)
        elsif @source[@index, 4] == "<!--"
          add_comment
        elsif @source[@index, 9].to_s.downcase == "<!doctype"
          add_doctype
        elsif @source[@index, 9] == "<![CDATA["
          add_cdata
        elsif @source[@index, 2] == "</"
          close_tag
        elsif @source[@index, 2] == "<?"
          skip_processing_instruction
        else
          add_tag
        end
      end
    end

    def read_text
      finish = @source.index("<", @index) || @source.length
      text = @source[@index...finish]
      @index = finish
      CGI.unescapeHTML(text)
    end

    def add_text(text)
      return if text.empty?

      current = @stack.last
      if current.children.last&.text?
        current.children.last.data << text
      else
        current.add_child(Node.new(:text, data: text))
      end
    end

    def add_comment
      finish = @source.index("-->", @index + 4)
      finish ||= @source.length
      data = @source[(@index + 4)...finish]
      @stack.last.add_child(Node.new(:comment, data: data))
      @index = [finish + 3, @source.length].min
    end

    def add_doctype
      finish = @source.index(">", @index + 2) || @source.length - 1
      raw = @source[(@index + 2)...finish].strip
      raw = raw.sub(/^doctype\s*/i, "")
      @document.add_child(Node.new(:doctype, data: raw.empty? ? "html" : raw))
      @index = finish + 1
    end

    def add_cdata
      finish = @source.index("]]>", @index + 9)
      finish ||= @source.length
      add_text(@source[(@index + 9)...finish])
      @index = [finish + 3, @source.length].min
    end

    def skip_processing_instruction
      finish = @source.index(">", @index + 2) || @source.length - 1
      @index = finish + 1
    end

    def close_tag
      match = @source[(@index + 2)..].match(/\A\s*([A-Za-z][\w:-]*)[^>]*>/)
      unless match
        add_text("<")
        @index += 1
        return
      end
      name = match[1].downcase
      @index += match[0].length + 2
      position = @stack.rindex { |node| node.element? && node.name == name }
      @stack.slice!(position..-1) if position && position.positive?
    end

    def add_tag
      match = @source[(@index + 1)..].match(/\A\s*([A-Za-z][\w:-]*)(.*?)(\/?)>/m)
      unless match
        add_text("<")
        @index += 1
        return
      end
      name = match[1].downcase
      attributes = parse_attributes(match[2])
      explicit_close = !match[3].empty?
      close_open_elements(name)
      node = Node.new(:element, name: name, attributes: attributes)
      @stack.last.add_child(node)
      @index += match[0].length + 1
      return if explicit_close || Node::VOID_ELEMENTS.include?(name)

      if RAW_ELEMENTS.include?(name)
        @stack << node
        end_tag = @source.downcase.index("</#{name}", @index)
        if end_tag
          add_text(@source[@index...end_tag])
          @index = end_tag
          close_tag
        else
          add_text(@source[@index..])
          @index = @source.length
        end
      else
        @stack << node
      end
    end

    def parse_attributes(source)
      attributes = {}
      index = 0
      while index < source.length
        index += 1 while index < source.length && source[index] =~ /\s/
        break if index >= source.length
        name_match = source[index..].match(/\A([^\s=\/>]+)/)
        break unless name_match
        name = name_match[1].downcase
        index += name_match[0].length
        index += 1 while index < source.length && source[index] =~ /\s/
        value = nil
        if source[index] == "="
          index += 1
          index += 1 while index < source.length && source[index] =~ /\s/
          if ["\"", "'"].include?(source[index])
            quote = source[index]
            index += 1
            finish = source.index(quote, index) || source.length
            value = source[index...finish]
            index = [finish + 1, source.length].min
          else
            finish = source[index..].index(/\s/) || (source.length - index)
            value = source[index, finish]
            index += finish
          end
        end
        attributes[name] ||= value.nil? ? "" : CGI.unescapeHTML(value)
      end
      attributes
    end

    def close_open_elements(name)
      current = @stack.last
      return unless current.element?

      if name == "li"
        close_until("li")
      elsif %w[dt dd].include?(name)
        close_until("dt", "dd")
      elsif %w[tr].include?(name)
        close_until("tr")
      elsif %w[td th].include?(name)
        close_until("td", "th")
      elsif name == "option"
        close_until("option")
      elsif @stack.any? { |node| node.element? && node.name == "p" } && (BLOCK_ELEMENTS.include?(name) || name == "p")
        close_until("p")
      elsif current.name == "a" && name == "a"
        close_until("a")
      end
    end

    def close_until(*names)
      position = @stack.rindex { |node| node.element? && names.include?(node.name) }
      @stack.slice!(position..-1) if position && position.positive?
    end

    def normalize_document
      html = @document.children.find { |node| node.element? && node.name == "html" }
      unless html
        html = Node.new(:element, name: "html")
        original = @document.children.reject { |node| node.type == :doctype }
        original.each(&:remove)
        @document.add_child(html)
        original.each { |node| html.add_child(node) }
      end
      head = html.children.find { |node| node.element? && node.name == "head" }
      body = html.children.find { |node| node.element? && node.name == "body" }
      unless head
        head = Node.new(:element, name: "head")
        html.prepend_child(head)
      end
      unless body
        body = Node.new(:element, name: "body")
        html.add_child(body)
      end
      # HTML5 places title/meta/link before body; move only obvious head content.
      html.children.reject { |node| node.equal?(head) || node.equal?(body) }.each do |node|
        next unless node.element? && %w[base link meta title style].include?(node.name)

        node.remove
        head.add_child(node)
      end
      html.children.reject { |node| node.equal?(head) || node.equal?(body) }.each do |node|
        next if node.parent.equal?(body)

        node.remove
        body.add_child(node)
      end
    end
  end
end
