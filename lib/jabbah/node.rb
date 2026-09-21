# frozen_string_literal: true

require "cgi/escape"

module Jabbah
  class Node
    VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr].freeze

    attr_accessor :parent
    attr_reader :type, :name, :attributes, :children, :data

    def initialize(type, name: nil, attributes: {}, data: nil)
      @type = type
      @name = name&.downcase
      @attributes = attributes.each_with_object({}) { |(key, value), result| result[key.to_s.downcase] = value }
      @data = data
      @children = []
      @parent = nil
    end

    def element? = type == :element
    def text? = type == :text
    def comment? = type == :comment
    def document? = type == :document

    def [](key)
      return @data if key.to_s == "text" && text?

      @attributes[key.to_s.downcase]
    end

    def []=(key, value)
      raise Error, "attributes are only available on elements" unless element?

      @attributes[key.to_s.downcase] = value
    end

    def add_child(child)
      child.remove if child.parent
      child.parent = self
      @children << child
      child
    end

    def prepend_child(child)
      child.remove if child.parent
      child.parent = self
      @children.unshift(child)
      child
    end

    def remove
      parent&.children&.delete(self)
      @parent = nil
      self
    end

    def each(&block)
      return enum_for(:each) unless block

      @children.each(&block)
    end

    def ancestors
      result = []
      current = parent
      while current
        result << current
        current = current.parent
      end
      result
    end

    def descendants(&block)
      nodes = []
      walk = lambda do |node|
        node.children.each do |child|
          nodes << child
          walk.call(child)
        end
      end
      walk.call(self)
      return nodes.each(&block) if block

      nodes.each
    end

    def at(selector)
      search(selector).first
    end

    def search(selector)
      Selector.search(self, selector)
    end

    def text
      return data.to_s if text?
      return "" if %i[comment doctype].include?(type)

      children.map(&:text).join
    end

    def clone
      copy = Node.new(type, name: name, attributes: attributes.dup, data: data)
      children.each { |child| copy.add_child(child.clone) }
      copy
    end

    def to_html(indent: nil, level: 0)
      case type
      when :document
        return render_children(nil, level) unless indent

        children.map { |child| "#{indent * level}#{child.to_html(indent: indent, level: level)}" }.join("\n")
      when :text
        CGI.escapeHTML(data.to_s)
      when :comment
        "<!--#{data}-->"
      when :doctype
        "<!DOCTYPE #{data || "html"}>"
      when :element
        opening = "<#{name}#{render_attributes}>"
        return opening if VOID_ELEMENTS.include?(name)
        closing = "</#{name}>"
        return "#{opening}#{render_children(nil, level)}#{closing}" unless indent
        return "#{opening}#{closing}" if children.empty?
        return "#{opening}#{render_children(nil, level)}#{closing}" if children.none?(&:element?)

        body = children.map { |child| "#{indent * (level + 1)}#{child.to_html(indent: indent, level: level + 1)}" }.join("\n")
        "#{opening}\n#{body}\n#{indent * level}#{closing}"
      end
    end

    private

    def render_attributes
      attributes.map do |key, value|
        value.nil? ? " #{key}" : " #{key}=\"#{CGI.escapeHTML(value.to_s)}\""
      end.join
    end

    def render_children(indent, level)
      children.map { |child| child.to_html(indent: indent, level: level) }.join
    end
  end
end
