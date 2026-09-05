# Sprint

A Mac app for reading long documents fast. Drop in a Markdown file, a text file,
or a PDF, and it shows you the words one at a time at a fixed point on a black
screen — a technique called rapid serial visual presentation.

The idea is that ordinary reading spends most of its time moving your eyes
rather than recognising words. Take the movement away and the ceiling goes up.

## Running it

```bash
./build.sh
open dist/Sprint.app
```

The first build takes a few minutes because the compiler has to process the
system frameworks; later builds take seconds.

## Using it

Drag a file onto the window, choose **File → Open**, or press ⌘V to read
whatever text is on the clipboard.

| Key | Does |
|---|---|
| Space | Play / pause |
| ← / → | Back / forward ten words |
| ⇧← | Back to the start of the sentence |
| ↑ / ↓ | Speed up / slow down by 25 words per minute |
| ⌘F | Full screen |
| Esc | Close the document |

The controls along the bottom do the same things, plus a progress bar you can
drag and a switch for how many words appear at once.

## The red letter

One letter in every word is red, and it stays on the same spot on screen no
matter how long the word is. That spot is the *optimal viewing position* — the
place the eye naturally lands, which is slightly left of the middle of a word:

| Word length | Red letter |
|---|---|
| 1 | 1st |
| 2–5 | 2nd |
| 6–9 | 3rd |
| 10+ | 4th |

Words are shifted left or right so that letter always sits on the centre line.
The font is monospaced for exactly this reason — with equal character widths the
offset is arithmetic, and the anchor never drifts by a fraction of a point.

## Pacing

The speed you set is the real throughput. Commas, full stops, paragraph breaks,
and unusually long words are each held a little longer, and the rest of the
words are shortened to compensate, so a thousand-word document at 300 wpm still
takes about three minutes and twenty seconds. Turn the punctuation pauses off
with the checkbox if you'd rather have a metronome.

## Tests

```bash
./test.sh
```

Covers the pivot table at every boundary, sentence and clause detection, the
pacing rules, chunk grouping, Markdown stripping, PDF reflow, and the engine's
seeking and timing behaviour.

## About the build scripts

There's no Xcode project and no Swift package here. This machine has the Command
Line Tools rather than full Xcode, and that install has two problems: its
SwiftPM manifest library doesn't match its own headers, so `swift build` can't
read a `Package.swift` at all, and a leftover file from a 2023 install breaks
every `import Foundation`.

`build.sh` sidesteps both. It calls the compiler directly and hides the stale
file behind an empty one for the duration of the build. `toolchain.sh` has the
details, and the workaround switches itself off automatically if the Command
Line Tools are ever reinstalled.

## Layout

```
Sources/Core/     Tokenizer, Chunker, DocumentLoader, ReaderEngine — no UI
Sources/App/      SwiftUI views and the app entry point
Tests/            A small test harness and the unit tests
Resources/        Info.plist for the app bundle
Samples/          Files to try it with
```
