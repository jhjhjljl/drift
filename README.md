# Drift

Kindle-like PDF novel reader for iPhone. I primarily built it for myself so that I can read pirated PDF novels on my phone.

## Open in Xcode

```bash
open Drift.xcodeproj
```

Select an iPhone simulator and run (⌘R). Set a **Signing Team** if Xcode asks.

## Import a PDF from Mac `~/Downloads` (simulator)

The simulator does **not** see your Mac Downloads folder directly. Put the file on the simulated iPhone first, then **import** inside Drift.

1. **Run Drift** on the simulator (⌘R).
2. **Copy the PDF onto the simulator** — drag `~/Downloads/YourNovel.pdf` from Finder onto the Simulator window.  
   It usually lands in the simulated **Files → Downloads** (or prompts you to save there).
3. In **Drift**, open the **library** (if you’re mid-book: tap the screen → **Library**).
4. Tap **+** (top right).
5. In the picker: **Browse** → **On My iPhone** → **Downloads** (or wherever the file appeared) → select your PDF.
6. Drift **imports** (copies) the file and opens it. Swipe up/down to turn pages.

If import fails with *“no readable text”*, the PDF is likely image-only (scanned); v1 needs selectable text.

### Physical iPhone

AirDrop or save the PDF to **Files** on the device, then the same **+** flow in Drift.

## Reading

- **Swipe up / down** → next / previous page  
- **Tap** anywhere → brief overlay → **Library**  
- Relaunch app → **resume** last book

Domain terms: [CONTEXT.md](CONTEXT.md).
