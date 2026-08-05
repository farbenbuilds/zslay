---
name: dod
description: Apply Data-Oriented Design (DoD) to optimize memory layout, data locality, and throughput while making ownership-aware performance decisions.
---

# DoD Skill (Data-Oriented Design)

## Purpose
DoD is an execution-only optimization for profiled C++ hot paths. It improves throughput by focusing on memory layout, data locality, and access patterns. DoD layouts are internal and transient; they are never canonical, shared, or persisted.

## When This Skill Should Trigger
Use this skill when working on profiled C++ hot paths where memory layout, data locality, or throughput materially affect performance:
- High-throughput data pipelines or batch processing
- Cache-sensitive loops or hot-path optimizations
- Memory-bound applications where layout impacts performance
- Large collections of similar entities with uniform update logic
- Systems where ownership-aware views (spans/views) reduce allocations across stable/public boundaries

## Core DoD Principles
1. Data is memory layout.
   - Design for how the hardware accesses memory.
   - Prioritize contiguous allocations to maximize cache hits.
   - View data as sequences and streams rather than individual objects.

2. Access patterns dictate storage format.
   - Use Structure of Arrays (SoA) for selective field access and SIMD efficiency.
   - Use Array of Structures (AoS) for whole-record updates or random access.
   - Evaluate layout trade-offs based on actual read/write frequencies.

3. Split data by frequency of access (Hot/Cold).
   - Segregate "hot" fields used in frequent loops from "cold" fields used for metadata.
   - Minimize cache pollution by excluding unused data from the primary processing path.

4. Favor batch processing over single-item operations.
   - Process multiple records in a single pass to amortize overhead.
   - Transform data in bulk to leverage hardware pipelining.

5. Minimize pointer chasing and indirection.
   - Avoid fragmented memory layouts and deep object trees.
   - Use offsets or indices instead of pointers where possible to keep data local.

6. Distinguish between owning containers and non-owning views.
   - Use spans or windowed views to process data without redundant copies.
   - Manage data lifetime in central buffers while exposing narrow, scoped views.

## DoD Scope and Boundaries
DoD is an internal, transient execution technique for profiled C++ work. Use it to reshape in-memory layouts inside a hot path, not to define persistence, serialization, or stable/public contracts. Keep layout details, handles, indices, and non-owning views inside that optimization boundary.

## Language-Specific Patterns
### C++
- Shape execution buffers from the hot-path data already inside the optimization boundary; keep layout details internal to that code path.
- Use `std::vector` or `std::array` for contiguous storage.
- Prefer `std::span` for non-owning views; ensure view lifetime never exceeds the source buffer.
- Use Structure of Arrays (SoA) for selective field access in hot loops.
- Use handles or indices instead of pointers to maintain data locality and stability.

## Mandatory Rules for the Agent
- Profile first; justify every DoD optimization with measured profiler evidence.
- Treat DoD layouts as internal, transient execution layouts; never canonical, shared, or persisted.
- Must not leak handles, indices, spans, or layout details across stable/public boundaries.
- Must not let DoD layouts define persistence, serialization, or stable/public contracts.
- Choose memory layout (SoA or AoS) based on specific access patterns.
- Batch transformations in bulk to amortize call overhead and improve throughput.
- Minimize pointer chasing by using contiguous buffers and numeric indices.
- Respect ownership boundaries and lifetime constraints for all non-owning views.

## Anti-Patterns (Must Avoid)
- Exposing SoA/AoS layout, handles, indices, or spans in persistence, serialization, or public contracts.
- Using DoD layouts as canonical state for domain logic, shared state, or long-lived records.
- Applying DoD prematurely to infrequent code paths or simple prototypes.
- Pointer chasing across fragmented memory layouts and deep object trees.
- Ignoring read/write access patterns when selecting between SoA and AoS.
- Creating views or spans that outlive their source buffers (lifetime violations).
- Over-optimizing cold paths where performance gains are negligible compared to complexity.

## Execution Workflow
1. Identify input/output boundaries before layout work begins.
2. Profile hot paths to identify bottlenecks using a profiler or benchmark.
3. Analyze access patterns to determine which fields are read or written together.
4. Select layout (SoA for selective access, AoS for whole-record processing).
5. Project hot-path data into an internal execution layout as justified by profiling.
6. Implement transformations using contiguous allocations and batch processing for efficiency.
7. Verify throughput and cache miss improvements with a follow-up profiler run.
8. Document ownership rules and lifetime constraints for all exposed data views.

## PR/Review Checklist
- Is the layout choice justified by profiler data or access-pattern analysis?
- Does the public representation remain stable with DoD details kept internal?
- Are hot and cold data split appropriately to maximize cache efficiency?
- Are batch transformations used where applicable to improve throughput?
- Are ownership and lifetime constraints clearly documented for all views?
- Was "when not to apply DoD" considered for this specific implementation?

## Output Format Expectations for the Agent
When proposing or implementing DoD changes, include:
1. Memory layout diagrams or SoA/AoS structure explanations.
2. Internal layout documentation showing how DoD structures map back to the source data.
3. Profiler evidence showing before/after metrics for cache misses or throughput.
4. Documentation of ownership rules and view lifetime constraints.
