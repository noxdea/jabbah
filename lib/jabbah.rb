# frozen_string_literal: true

require_relative "jabbah/version"
require_relative "jabbah/node"
require_relative "jabbah/document"
require_relative "jabbah/parser"
require_relative "jabbah/selector"
require_relative "jabbah/sanitize"
require_relative "jabbah/extract"

module Jabbah
  class Error < StandardError; end

  def self.parse(input, encoding: :auto)
    Document.parse(input, encoding: encoding)
  end

  def self.fragment(input, context: "div")
    Document.fragment(input, context: context)
  end
end
