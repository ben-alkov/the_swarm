<!-- markdownlint-disable link-image-style -->

# Bookmarks

Progressive disclosure for task-specific documentation and references.

## Table of Contents

- [Architecture and Patterns](#architecture-and-patterns)
- [Usage Examples](#usage-examples)

---

## Architecture and Patterns

### [v2 Design Document](./docs/2-designs/2026-02-25-v2.md)

Definitive architecture rationale — pattern taxonomy, platform constraints,
migration path, and scale limits.

### [v2 Implementation Plan](./docs/3-implementation_plans/2026-02-25-v2.md)

Step-by-step implementation plan for the v2 architecture.

---

## Usage Examples

### [PR Review Example](config/examples/pr-review.yaml)

Fan-out pattern — parallel security, performance, and quality reviewers.

### [Pipeline: Implement then Review](config/examples/pipeline-implement-review.yaml)

Pipeline pattern — stage 1 implements, stage 2 reviews.

### [Speculative Refactor](config/examples/speculative-refactor.yaml)

Speculative pattern — competing implementations evaluated by a judge.

### [Map-Reduce Audit](config/examples/map-reduce-audit.yaml)

Map-reduce pattern — parallel mappers per directory, single reducer merges.

### [Task Graph Migration](config/examples/task-graph-migration.yaml)

Task-graph pattern — DAG with dependency edges between stages.

---

**Tip**: Use `/bookmark <url> <description>` to add to this list.
