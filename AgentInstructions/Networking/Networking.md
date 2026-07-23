# Roblox Networking Reference: Buffers & Serialization

Reference doc for an AI coding agent working on Roblox networking tasks (RemoteEvents/RemoteFunctions, DataStores, replication). Covers the `buffer` library, `EncodingService`, and the `Sera` serialization module.

---

## 1. Why Buffers for Networking

- **Serialization** = converting complex data (tables, Instances, CFrames, etc.) into a transmittable/storable format (bytes, JSON). **Deserialization** reverses this.
- Tables and complex objects like physical parts can't be sent directly to DataStores or efficiently over RemoteEvents.
- `table`-based remote events carry more overhead per call than raw bytes. A `buffer` is a **fixed-size raw memory block** of binary data — sending buffers instead of tables shrinks payload size and reduces bandwidth.
- Trade-off: buffers require more manual setup (explicit sizes, offsets, types) than plain tables.
- Buffers can be created/manipulated on client or server — location doesn't matter.

---

## 2. Creating a Buffer

```lua
local buf = buffer.create(size) -- size is in BYTES
```

- Max buffer size: **1 GiB** (1,073,741,824 bytes — binary base-2 gigabyte, not the decimal 1,000,000,000).
- All bytes are zero-initialized on creation.
- Reminder: 8 bits = 1 byte.

---

## 3. Writing & Reading Fixed-Width Values

### Integers
```lua
buffer.writeu8(buf, offset, value)  -- unsigned 8-bit
buffer.writei8(buf, offset, value)  -- signed 8-bit
buffer.writeu16 / writei16 / writeu32 / writei32 / ...
buffer.readu8(buf, offset)
```
- `U` = unsigned (positive only). `I` = signed (allows negatives).
- The numeric suffix (8/16/32/64) is **bits**, not bytes. Divide by 8 to get bytes consumed. E.g. `writeu16` consumes 2 bytes.
- Each width has a fixed range:
  - Unsigned 8-bit: `0` to `255`
  - Signed 8-bit: `-128` to `127` (note `128 + 127 = 255`)
  - 16/32/64-bit variants follow the same pattern with proportionally larger ranges.
- Writing a value outside the range for a given width will fail — pick the smallest width that fits your data's actual range to save bytes.

### Floats
```lua
buffer.writef32(buf, offset, value) -- single precision
buffer.writef64(buf, offset, value) -- double precision
```
- Use for decimal/fractional values.
- `f64` gives more precision than `f32` at double the storage cost (8 bytes vs 4 bytes).

### Offsets
- Offsets start at `0` and are **byte-based**, not automatic — you must track them manually based on how many bytes the previous write consumed.
- Example: writing `u16` (2 bytes) at offset 0, then `i32` (4 bytes) must be written at offset 2, then a subsequent `u8` write must be at offset 6 (2 + 4).
- **Perspective note:** Luau numbers are represented internally using 64 bits (8 bytes). Packing 3 small values into a 3-byte buffer instead of storing them as native Luau numbers (24 bytes) is an 8x size reduction — this is the core payoff of using buffers for networking.

---

## 4. String Data

```lua
buffer.writestring(buf, offset, str)      -- write a string into an existing buffer
buffer.readstring(buf, offset, length)    -- read a string out
local buf2 = buffer.fromstring(str)       -- create a NEW buffer directly from a string
local str2 = buffer.tostring(buf2)        -- convert an entire buffer back to a string
print(buffer.len(buf2))                   -- byte length of a buffer
```

**Byte cost per character (Roblox strings are UTF-8 encoded):**
| Character type | Bytes per character |
|---|---|
| Standard ASCII (letters, space, punctuation) | 1 |
| Accented characters | 2 |
| Asian-language characters (CJK, etc.) | 3 |
| Emoji | 4 |

- Plain Luau string operations count raw bytes, not "characters" — a string with accents/CJK/emoji will report a higher `buffer.len` than its visible character count.
- Roblox's `utf8` library exists to correctly decode/iterate multi-byte characters (not detailed further here — separate topic).

---

## 5. Bit-Level Read/Write

```lua
buffer.writebits(buf, bitOffset, bitCount, value)
buffer.readbits(buf, bitOffset, bitCount)
```

- Same size-tracking rule as byte writes, but offsets are counted in **bits**, and you specify `bitCount` explicitly.
- You do not have to fill an entire byte with bit-writes — partial usage is valid, you just need enough allocated space for whatever you write.
- Each `bitCount` has its own valid value range (analogous to the byte-integer ranges above) — pick a `bitCount` large enough to hold the max value you need, and no larger, to keep payloads minimal.

---

## 6. Utility Functions

```lua
buffer.copy(targetBuf, targetOffset, sourceBuf, sourceOffset, byteCount)
```
Copies a run of bytes from one buffer into another at specified offsets.

```lua
buffer.fill(buf, offset, count, value)
```
Sets `count` bytes starting at `offset` to a given unsigned 8-bit value. Useful for zeroing out/resetting memory regions before reuse.

---

## 7. Compression: EncodingService

Compression operates on already-serialized (binary) data — it doesn't perform serialization itself.

```lua
local compressed = EncodingService:CompressBuffer(buf, Enum.CompressionAlgorithm.Zstandard, level)
local decompressed = EncodingService:DecompressBuffer(compressed, Enum.CompressionAlgorithm.Zstandard)
local size = EncodingService:GetDecompressedBufferSize(compressed, Enum.CompressionAlgorithm.Zstandard)
```

- **Zstandard** is currently the only supported algorithm. It's lossless (no data alteration) and works best on data with **repeating patterns/strings**.
- Compression level range: **-7 to 22**. Default is 1 if omitted.
  - Higher level → smaller output, slower compression.
  - Lower level → faster, less size reduction.
- `GetDecompressedBufferSize` lets you check the eventual decompressed size without actually decompressing — cheap pre-check.
- Compression gains are highly data-dependent; only reaches for it when payloads have redundancy (e.g., repeated struct patterns across many entries), not for small one-off unique buffers.

---

## 8. Schema-Based Serialization: Sera (by Loleris)

A low-level module for defining a typed schema and serializing tables to/from buffers with minimal boilerplate.

```lua
local Sera = require(path.to.Sera)

-- Define schema: field name -> type
local schema = {
    health = Sera.u16,
    position = Sera.Vector3,
    name = Sera.string8,
}

-- Serialize
local data, err = Sera.serialize(schema, {
    health = 150,
    position = Vector3.new(x, y, z),
    name = "Player1",
})
if err then error(err) end

-- Send `data` (a buffer) over a RemoteEvent

-- Deserialize (server or client)
local decoded = Sera.deserialize(schema, data)
```

### Delta Serialization
For sending only *changed* fields (useful for frequent state updates):

```lua
local deltaBuf, err = Sera.deltaSerialize(schema, { health = 175 })

-- On receiving end
local deltaDecoded = Sera.deltaDeserialize(schema, deltaBuf)

-- Merge into existing state
for key, value in deltaDecoded do
    state[key] = value
end
```

This avoids re-sending an entire state object when only one or two fields changed — pairs well with buffer-based networking to minimize per-update bandwidth.

---

## 9. Practical Guidance for Agent Use

When asked to implement Roblox networking that should minimize bandwidth:
1. Prefer `buffer` + `Sera` schema serialization over sending raw Luau tables through RemoteEvents for frequently-fired or high-volume events.
2. Choose the smallest integer/float width that covers the actual value range needed (don't default to 32/64-bit if 8/16-bit suffices).
3. Track offsets manually and precisely — an off-by-N-bytes offset error is the most common bug source here.
4. Use delta serialization for state that updates incrementally (health, position ticks, etc.) rather than resending the full payload each time.
5. Only reach for `EncodingService` compression when payloads have exploitable repetition; test actual size before/after, since compression has diminishing or negative returns on small/unique buffers.
6. Reserve `DataStore` binary storage (buffers/strings from `buffer.tostring`) for cases where table storage is verbose or hits size limits.