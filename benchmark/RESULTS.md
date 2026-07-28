# Parser benchmark results

The benchmark is generated in memory and can be reproduced with:

```bash
bundle exec rake bench
```

## 2026-07-28

- Environment: Ruby 4.0.0, arm64 Darwin 25.3.0
- 100,000 Prim layer: 1.351 seconds, resident memory +147.1 MiB
- 1,000,000-vertex Mesh: 2.093 seconds, resident memory +208.5 MiB

Resident-memory growth is sampled immediately before and after each parse.
Results vary by Ruby version, allocator, hardware, and concurrent system load.
