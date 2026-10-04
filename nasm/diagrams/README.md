# Diagram index

Register views, memory layouts, and control flow: the diagrams we use to keep the machine state straight. PNG images are embedded in the corresponding lessons. The PNGs are tracked in Git; the editable DOT sources currently exist only in the local working tree. When those sources are available, edit them and run the following from `nasm/` to regenerate the images:

```sh
for source in diagrams/*.dot; do
    dot -Tpng "$source" -o "${source%.dot}.png"
done
```

| Chapter | PNG | Editable source |
| --- | --- | --- |
| 00 | [00_toolchain](00_toolchain.png) | `00_toolchain.dot` (local) |
| 01 | [01_register_views](01_register_views.png) | `01_register_views.dot` (local) |
| 02 | [02_memory_bytes](02_memory_bytes.png) | `02_memory_bytes.dot` (local) |
| 03 | [03_flags](03_flags.png) | `03_flags.dot` (local) |
| 04 | [04_loop](04_loop.png) | `04_loop.dot` (local) |
| 05 | [05_stack_frame](05_stack_frame.png) | `05_stack_frame.dot` (local) |
| 06 | [06_abi](06_abi.png) | `06_abi.dot` (local) |
| 07 | [07_strings](07_strings.png) | `07_strings.dot` (local) |
| 08 | [08_write_all](08_write_all.png) | `08_write_all.dot` (local) |
| 09 | [09_struct_nodes](09_struct_nodes.png) | `09_struct_nodes.dot` (local) |
| 10 | [10_simd_lanes](10_simd_lanes.png) | `10_simd_lanes.dot` (local) |
| 11 | [11_atomic_updates](11_atomic_updates.png) | `11_atomic_updates.dot` (local) |
| 12 | [12_decimal_pipeline](12_decimal_pipeline.png) | `12_decimal_pipeline.dot` (local) |
| 13 | [13_elf](13_elf.png) | `13_elf.dot` (local) |
| 14 | [14_modes](14_modes.png) | `14_modes.dot` (local) |
| 15 | [15_input_contracts](15_input_contracts.png) | `15_input_contracts.dot` (local) |
