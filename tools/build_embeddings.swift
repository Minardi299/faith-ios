#!/usr/bin/env swift

// Bakes the corpus retrieval index at compile time.
//
// Reads canon.json + sidecar JSON files, computes a single L2-normalised
// vector per non-stub passage with body text by averaging the per-token
// `NLEmbedding.wordEmbedding(for: .english)` vectors of its words, and
// writes the result in the binary format `EmbeddingIndex` hydrates from.
//
// Word embedding rather than sentence embedding because Apple's English
// sentence-embedding model is *missing on the iOS Simulator runtime*
// (`sentenceEmbedding(for: .english)` returns nil). Word embeddings have
// been bundled in NaturalLanguage since iOS 13 and work cross-platform.
//
// Usage:
//   swift tools/build_embeddings.swift \
//     faith-ios/Resources/embeddings.bin \
//     faith-ios/Resources/canon.json \
//     faith-ios/Resources/study-stories.json \
//     faith-ios/Resources/study-introductions.json
//
// File format (little-endian throughout):
//   magic     UInt32   "EMB1" (0x454D4231)
//   version   UInt32   1
//   count     UInt32   number of entries
//   dim       UInt32   per-entry vector dimension
//   entries × {
//     idLen   UInt16
//     id      UInt8 × idLen   (UTF-8)
//     vec     Float32 × dim   (L2-normalised)
//   }

import Foundation
import NaturalLanguage

struct Line: Decodable {
    let text: String
    enum CodingKeys: String, CodingKey { case text }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try c.decode(String.self, forKey: .text)
    }
}

struct Passage: Decodable {
    let id: String
    let lines: [Line]
    let isStub: Bool
    enum CodingKeys: String, CodingKey { case id, lines, isStub }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.lines = try c.decodeIfPresent([Line].self, forKey: .lines) ?? []
        self.isStub = try c.decodeIfPresent(Bool.self, forKey: .isStub) ?? false
    }
}

struct Payload: Decodable {
    let entries: [Passage]
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: swift build_embeddings.swift <output.bin> <input1.json> [input2.json ...]\n".utf8))
    exit(2)
}
let outputPath = args[1]
let inputPaths = Array(args[2...])

print("→ Output: \(outputPath)")
print("→ Inputs: \(inputPaths.joined(separator: ", "))")

guard let embedder = NLEmbedding.wordEmbedding(for: .english) else {
    FileHandle.standardError.write(Data("✘ NLEmbedding.wordEmbedding(for: .english) returned nil\n".utf8))
    exit(1)
}
let dim = embedder.dimension
print("→ NLEmbedding word dim = \(dim)")

var passages: [Passage] = []
for path in inputPaths {
    let url = URL(fileURLWithPath: path)
    do {
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        passages.append(contentsOf: payload.entries)
        print("  loaded \(payload.entries.count) entries from \(url.lastPathComponent)")
    } catch {
        FileHandle.standardError.write(Data("✘ failed to read \(path): \(error)\n".utf8))
        exit(1)
    }
}

// Skip stubs, empty bodies, and SuttaCentral repetition micro-entries
// (< 200 chars) — they're noise that pollutes retrieval and adds nothing
// unique on top of the parent suttas.
let minBodyLen = 200
let withBody: [(p: Passage, body: String)] = passages.compactMap { p in
    guard !p.lines.isEmpty, !p.isStub else { return nil }
    let body = p.lines
        .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    guard body.count >= minBodyLen else { return nil }
    return (p, body)
}
print("→ Embedding \(withBody.count) passages (skipped \(passages.count - withBody.count) stubs / short / empty)")

func passageVector(_ text: String) -> [Float]? {
    let lowered = text.lowercased()
    var sum = [Double](repeating: 0, count: dim)
    var n = 0
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = lowered
    tokenizer.enumerateTokens(in: lowered.startIndex..<lowered.endIndex) { range, _ in
        let token = String(lowered[range])
        if let v = embedder.vector(for: token), v.count == dim {
            for i in 0..<dim { sum[i] += v[i] }
            n += 1
        }
        return true
    }
    guard n > 0 else { return nil }
    var vec = [Float](repeating: 0, count: dim)
    var sumSq: Float = 0
    let inv = 1.0 / Double(n)
    for i in 0..<dim {
        let f = Float(sum[i] * inv)
        vec[i] = f
        sumSq += f * f
    }
    let mag = sqrt(sumSq)
    guard mag > 0 else { return nil }
    for i in 0..<dim { vec[i] /= mag }
    return vec
}

struct Vec { let id: String; let f: [Float] }
var vectors: [Vec] = []
vectors.reserveCapacity(withBody.count)
let started = Date()

for (i, item) in withBody.enumerated() {
    let p = item.p
    let body = item.body
    let capped: String = body.count > 4000 ? String(body.prefix(4000)) : body
    if let v = passageVector(capped) {
        vectors.append(Vec(id: p.id, f: v))
    }
    if (i + 1) % 500 == 0 {
        let elapsed = Date().timeIntervalSince(started)
        let rate = Double(i + 1) / max(elapsed, 0.001)
        let eta = Double(withBody.count - (i + 1)) / max(rate, 0.001)
        print(String(format: "  %d / %d  (%.1f passages/s, eta %.0fs)", i + 1, withBody.count, rate, eta))
    }
}

let elapsed = Date().timeIntervalSince(started)
print(String(format: "→ Computed %d vectors in %.1fs (%.1f passages/s)", vectors.count, elapsed, Double(vectors.count) / max(elapsed, 0.001)))

var data = Data()
func appendLE<T: FixedWidthInteger>(_ value: T) {
    var v = value.littleEndian
    withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
}
appendLE(UInt32(0x454D4231))
appendLE(UInt32(1))
appendLE(UInt32(vectors.count))
appendLE(UInt32(dim))
for v in vectors {
    let idBytes = Data(v.id.utf8)
    appendLE(UInt16(idBytes.count))
    data.append(idBytes)
    v.f.withUnsafeBufferPointer { buf in
        if let p = buf.baseAddress {
            data.append(UnsafeBufferPointer(start: p, count: buf.count))
        }
    }
}

let outURL = URL(fileURLWithPath: outputPath)
do {
    try data.write(to: outURL, options: .atomic)
    print(String(format: "✔ wrote %.1f MB → %@", Double(data.count) / 1024.0 / 1024.0, outputPath))
} catch {
    FileHandle.standardError.write(Data("✘ write failed: \(error)\n".utf8))
    exit(1)
}
