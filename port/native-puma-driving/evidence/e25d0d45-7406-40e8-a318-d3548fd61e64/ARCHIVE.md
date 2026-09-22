# Lossless failed-display log archive

The failed Xvfb startup produced 238,148 repeated diagnostic lines (14,348,323
bytes). `xvfb.log.gz` preserves its exact bytes using deterministic gzip. The
uncompressed original is also available in primary commit `2bf64c1`.

- Original SHA256: `be477c464798f7b56d0fc073ad03ef7d203064569e3ade6c83412b006b1c20ab`
- Gzip bytes: 55,933
- Gzip SHA256: `289ebb2fbec5f049b63a8ddd1cd111e6d84a9be5caf3c9b0c9515fda812748e1`

Decompression was verified byte-for-byte before replacing the plain copy.
The run remains FAILED; its summary and other logs are unchanged.
