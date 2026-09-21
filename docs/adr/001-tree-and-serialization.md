# ADR 001: Tree and serialization only, no DOM API

- Status: accepted
- Date: 2026-09-21
- Author: Yudai Takada

## Context

Jabbah is shared by reader-mode applications that need to inspect and safely
render static HTML. A browser-compatible live DOM would require JavaScript,
mutation observers, layout, and a large API surface that these applications do
not need.

## Decision

Jabbah exposes a snapshot tree of document, element, text, comment, and doctype
nodes. It provides traversal, CSS selector queries, cloning, and deterministic
serialization. It does not implement a browser DOM, event dispatch, JavaScript,
or layout. Sanitization operates on a cloned snapshot and returns a document.

## Consequences

The library remains dependency-free and small enough for local documents,
feeds, and mail. Applications that need live DOM behavior must use a dedicated
browser engine; that is intentionally outside Jabbah's scope.
