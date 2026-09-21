# frozen_string_literal: true

module Jabbah
  module Selector
    module_function

    def search(root, expression)
      groups = split_groups(expression.to_s)
      root.descendants.select { |node| node.element? && groups.any? { |group| matches?(node, group) } }
    end

    def matches?(node, group)
      parts = parse_group(group)
      return false if parts.empty? || !simple_match?(node, parts[-1][0])

      current = node
      (parts.length - 2).downto(0) do |index|
        simple, combinator = parts[index]
        if combinator == :child
          current = current.parent
          return false unless current&.element? && simple_match?(current, simple)
        else
          current = current.ancestors.find { |ancestor| ancestor.element? && simple_match?(ancestor, simple) }
          return false unless current
        end
      end
      true
    end

    def split_groups(expression)
      groups = []
      start = 0
      quote = nil
      depth = 0
      expression.each_char.with_index do |char, index|
        if quote
          quote = nil if char == quote
        elsif ["\"", "'"].include?(char)
          quote = char
        elsif char == "[" || char == "("
          depth += 1
        elsif char == "]" || char == ")"
          depth -= 1
        elsif char == "," && depth.zero?
          groups << expression[start...index].strip
          start = index + 1
        end
      end
      groups << expression[start..].to_s.strip
      groups.reject(&:empty?)
    end

    def parse_group(group)
      simples = []
      combinators = []
      buffer = +""
      quote = nil
      depth = 0
      whitespace = false
      flush = lambda do
        next if buffer.strip.empty?

        simples << parse_simple(buffer.strip)
        buffer.clear
        if simples.length > 1 && combinators.length < simples.length - 1
          combinators << (whitespace ? :descendant : :child)
        end
        whitespace = false
      end

      group.each_char do |char|
        if quote
          buffer << char
          quote = nil if char == quote
        elsif ["\"", "'"].include?(char)
          quote = char
          buffer << char
        elsif char == "[" || char == "("
          depth += 1
          buffer << char
        elsif char == "]" || char == ")"
          depth -= 1
          buffer << char
        elsif depth.zero? && char == ">"
          flush.call
          whitespace = false
          combinators << :child if simples.length > combinators.length
        elsif depth.zero? && char.match?(/\s/)
          flush.call
          whitespace = true
        else
          buffer << char
        end
      end
      flush.call
      # The scanner above records explicit child combinators and implicit spaces;
      # normalize the relation list to one relation per adjacent simple selector.
      relations = group_relations(group, simples.length)
      simples.each_with_index.map { |simple, index| [simple, relations[index]] }
    end

    def group_relations(group, count)
      return [] if count < 2

      relations = []
      quote = nil
      depth = 0
      pending_space = false
      group.each_char do |char|
        if quote
          quote = nil if char == quote
        elsif ["\"", "'"].include?(char)
          quote = char
        elsif char == "[" || char == "("
          depth += 1
        elsif char == "]" || char == ")"
          depth -= 1
        elsif depth.zero? && char.match?(/\s/)
          pending_space = true
        elsif depth.zero? && char == ">"
          relations << :child
          pending_space = false
        elsif depth.zero? && !char.match?(/\s/)
          if pending_space && relations.length < count - 1
            relations << :descendant unless relations.last == :child
          end
          pending_space = false
        end
      end
      relations.fill(:descendant, relations.length...count - 1)
    end

    def parse_simple(source)
      result = {tag: nil, ids: [], classes: [], attrs: [], pseudos: []}
      rest = source.dup
      if (tag = rest[/\A(?:[A-Za-z][\w-]*|\*)/])
        result[:tag] = tag.downcase unless tag == "*"
        rest = rest[tag.length..]
      end
      until rest.empty?
        case rest[0]
        when "#", "."
          marker = rest[0]
          match = rest[1..].match(/\A[\w:-]+/)
          break unless match
          result[marker == "#" ? :ids : :classes] << match[0]
          rest = rest[match[0].length + 1..]
        when "["
          finish = matching_bracket(rest, "[", "]")
          break unless finish
          content = rest[1...finish].strip
          if (match = content.match(/\A([^\s~|^$*!=]+)\s*(?:(\^=|\$=|\*=|~=|\|=|!=|=)\s*["']?(.*?)["']?)?\z/))
            result[:attrs] << [match[1].downcase, match[2], match[3]&.strip]
          end
          rest = rest[(finish + 1)..]
        when ":"
          match = rest.match(/\A:([\w-]+)(?:\((.*?)\))?/)
          break unless match
          result[:pseudos] << [match[1].downcase, match[2]]
          rest = rest[match[0].length..]
        else
          rest = rest[1..]
        end
      end
      result
    end

    def matching_bracket(text, opening, closing)
      depth = 0
      quote = nil
      text.each_char.with_index do |char, index|
        if quote
          quote = nil if char == quote
        elsif ["\"", "'"].include?(char)
          quote = char
        elsif char == opening
          depth += 1
        elsif char == closing
          depth -= 1
          return index if depth.zero?
        end
      end
      nil
    end

    def simple_match?(node, simple)
      return false unless node.element?
      return false if simple[:tag] && node.name != simple[:tag]
      return false unless simple[:ids].all? { |id| node["id"] == id }
      classes = node["class"].to_s.split
      return false unless simple[:classes].all? { |name| classes.include?(name) }
      return false unless simple[:attrs].all? { |attribute| attribute_match?(node, attribute) }
      simple[:pseudos].all? { |pseudo, value| pseudo_match?(node, pseudo, value) }
    end

    def attribute_match?(node, (name, operator, expected))
      actual = node[name]
      return !actual.nil? if operator.nil?
      return false if actual.nil?

      case operator
      when "=" then actual == expected
      when "!=" then actual != expected
      when "^=" then actual.start_with?(expected.to_s)
      when "$=" then actual.end_with?(expected.to_s)
      when "*=" then actual.include?(expected.to_s)
      when "~=" then actual.split.include?(expected.to_s)
      when "|=" then actual == expected || actual.start_with?("#{expected}-")
      else false
      end
    end

    def pseudo_match?(node, pseudo, value)
      siblings = node.parent&.children&.select(&:element?) || []
      index = siblings.index(node)
      case pseudo
      when "first-child" then index == 0
      when "last-child" then index == siblings.length - 1
      when "only-child" then siblings.length == 1
      when "root" then node.name == "html"
      when "empty" then node.children.none? { |child| child.element? || (child.text? && !child.data.empty?) }
      when "nth-child" then nth?(index.to_i + 1, value)
      when "not" then !simple_match?(node, parse_simple(value.to_s))
      else false
      end
    end

    def nth?(index, expression)
      value = expression.to_s.strip.downcase
      return index == value.to_i if value.match?(/\A\d+\z/)
      return index.odd? if value == "odd"
      return index.even? if value == "even"
      if (match = value.match(/\A([+-]?\d*)n(?:\s*([+-])\s*(\d+))?\z/))
        coefficient = match[1].empty? || match[1] == "+" ? 1 : match[1] == "-" ? -1 : match[1].to_i
        offset = match[3].to_i * (match[2] == "-" ? -1 : 1)
        return (index - offset) * coefficient >= 0 && (index - offset) % coefficient.zero?
      end
      false
    end
  end
end
