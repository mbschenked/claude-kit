# API-app path: document summarization via the Anthropic API

This skill, when run inside Claude Code, ingests documents with the `Read` tool. If you are instead **building an API application** that summarizes documents, use the native document mechanism — it is citation-anchored and handles PDFs as text + page images. Source: Day 7 research brief (`artifacts/week2/research-brief-anthropic-doc-workflows.md`), all findings T1 from `platform.claude.com/docs`.

## Ingestion — `document` content block

`source.type` is one of:
- `url` — a hosted PDF URL (no upload step).
- `base64` — inline, `media_type: "application/pdf"`.
- `file` — a `file_id` from the Files API (`source.file_id`).

Limits: **32 MB per request** (whole payload), **600 pages** (100 for 200k-context models), standard unencrypted PDF only. Each page is processed as **both** an image and extracted text — this is what enables chart/figure understanding. Dense PDFs can exhaust the context window before the page ceiling; split large docs in a preprocessing step.

## Files API (beta)

- Required header: `anthropic-beta: files-api-2025-04-14`.
- Endpoints: `POST /v1/files` (upload), `GET /v1/files`, `GET/DELETE /v1/files/{id}`. Download (`GET /v1/files/{id}/content`) works only for files *created* by skills/code-execution, not for files you uploaded.
- 500 MB/file, workspace-scoped, retained until explicitly deleted, **not** ZDR-eligible, **not** on Bedrock/Vertex. SDK: `client.beta.files.*`. File ops are free; file content is billed as input tokens.

## Citations — the targeted-Q&A mechanism (GA, no beta header)

Add `"citations": {"enabled": true}` to each `document` block (all-or-none within a request). Responses come back as interleaved text blocks, each carrying a `citations` array:
- PDFs → `page_location` with `start_page_number` / `end_page_number` (1-indexed, exclusive end).
- Plain text → `char_location`.
- `cited_text` (the exact quoted span) does **not** count against output tokens.

Compatible with prompt caching and batch. **Hard incompatibility: citations + Structured Outputs returns API 400.** If you need schema-constrained JSON, do that in a separate Messages call from the cited-summary call.

## Build notes for an API-side summarizer

- Use `file_id` source + `citations: enabled` so every summary sentence is anchored to a page range — this is the API-native version of this skill's "ground every claim" discipline.
- Put `cache_control: {type: "ephemeral"}` on the document block for repeated Q&A over the same doc.
- For `.docx` input: not a supported `document` type — convert to PDF first (client-side, e.g. a bundled generator à la the `anki-deck` skill's `generate.py`), then upload as `application/pdf`.
- Polished `.docx`/`.pptx`/`.pdf` *output* is a separate server-side path: Anthropic's first-party `docx`/`pptx`/`pdf` skills in the code-execution sandbox (`container.skills` + `code_execution_20250825`), needing both `files-api-2025-04-14` and `skills-2025-10-02` betas. Out of scope for summarization; noted for completeness.
