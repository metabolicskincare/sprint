# Sprint

A Mac app for reading long documents fast. Drop in a Markdown file, a text file,
or a PDF, and it shows you the words one at a time at a fixed point on a black
screen — a technique called rapid serial visual presentation.

The idea is that ordinary reading spends most of its time moving your eyes
rather than recognising words. Take the movement away and the ceiling goes up.

## Installing it

Download the latest `Sprint.app.zip` from the
[releases page](../../releases), unzip it, and drag Sprint to your
Applications folder.

**The first time you open it, macOS will refuse.** Sprint isn't signed with a
paid Apple Developer certificate, so macOS shows a warning about an
unidentified developer. To get past it, **right-click the app and choose
Open**, then click Open in the dialog. You only have to do this once — after
that it launches normally.

Requires macOS 14 (Sonoma) or later.

## Building it yourself

```bash
./build.sh
open dist/Sprint.app
```

No Xcode project, no package manager, no dependencies — the Command Line Tools
are enough. The first build takes a few minutes because the compiler has to
process the system frameworks; later builds take seconds.

Note that the app doesn't pick up a rebuild while it's running. Quit it and
reopen it after making changes.

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

There's no Xcode project and no Swift package here. `build.sh` calls the
compiler directly and assembles the result into an app bundle, which keeps the
whole thing to three shell scripts and some Swift.

`toolchain.sh` also carries a workaround for a specific broken Command Line
Tools install, where a leftover file from an older version declares a module
twice and breaks every `import Foundation`. If your machine isn't affected the
workaround switches itself off, so it costs you nothing.

## Why it isn't signed

Signing and notarising a Mac app requires an Apple Developer account at $99 a
year. This is a small free tool, so it ships unsigned and you get the one-time
right-click dance described above. The source is all here if you'd rather build
it yourself and skip that.

## Layout

```
Sources/Core/     Tokenizer, Chunker, DocumentLoader, ReaderEngine — no UI
Sources/App/      SwiftUI views and the app entry point
Tests/            A small test harness and the unit tests
Resources/        Info.plist for the app bundle
Samples/          Files to try it with
```
