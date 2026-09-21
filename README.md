<h1 align="center">Jabbah</h1>

<p align="center"><strong>Parse, query, and clean real-world HTML in pure Ruby.</strong></p>

<p align="center">
  <a href="https://rubygems.org/gems/jabbah"><img src="https://img.shields.io/gem/v/jabbah" alt="Gem version"></a>
  <a href="https://github.com/noxdea/jabbah/actions/workflows/main.yml"><img src="https://github.com/noxdea/jabbah/actions/workflows/main.yml/badge.svg" alt="CI status"></a>
  <img src="https://img.shields.io/badge/Ruby-3.2%2B-cc342d" alt="Ruby 3.2 or newer">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#sanitization">Sanitization</a> ·
  <a href="#article-extraction">Article extraction</a>
</p>

---

Jabbah is a dependency-free HTML parser for static documents and reader
applications. It tolerates broken markup, builds a traversable tree, supports
a useful CSS selector subset, and provides conservative sanitization. It
never fetches pages or executes JavaScript. The name comes from ν Scorpii
and the Arabic *jabha*, “forehead.”

## Features

- Document and fragment parsing with implicit element closing
- Traversal, cloning, serialization, and common CSS selectors
- UTF-8, BOM, and declared-charset decoding
- Sanitization profiles for documents, feeds, and mail
- Remote-image blocking and readability-style article extraction
- No runtime dependencies or native extensions

## Installation

Add `gem "jabbah"` to your Gemfile and run `bundle install`, or install directly:

```sh
gem install jabbah
```

Requires Ruby 3.2 or newer.

## Quick start

```ruby
require "jabbah"

document = Jabbah.parse('<main><h1>Hello</h1><p class="lead">Welcome.</p></main>')
puts document.at("main h1").text          # => Hello
puts document.search("p.lead").first.text # => Welcome.
puts document.to_html
```

`Jabbah.parse` returns a `Jabbah::Document`. Use `Jabbah.fragment` for
fragments without document wrappers. `#at` returns the first match and
`#search` returns every match.

## Sanitization

```ruby
safe = Jabbah::Sanitize.clean(
  document,
  profile: :feed,
  base_url: "https://example.com/"
)
puts safe.to_html
puts "Blocked images: #{safe.blocked_count}"
```

The `:docs`, `:feed`, and `:mail` profiles remove active elements and
unsafe URLs. Remote images are blocked by default, with their original URL
retained in `data-blocked-src`; `cid:` images are preserved. Sanitization
returns a clone, leaving the original document unchanged.

## Article extraction

```ruby
article = Jabbah::Extract.article(safe)
puts article[:title] if article
puts article[:content].text if article
```

Extraction is heuristic and may return `nil` when no article-like content
is found. See the [tree and serialization decision](docs/adr/001-tree-and-serialization.md)
for the underlying design.

## Development

```sh
bundle install
bundle exec rake test
```

## License

[MIT](LICENSE.txt)
