# Drift

A phone reader for locally stored PDF novels, reflowed to feel like a dedicated e-reader.

## Language

**Import**:
The user picks a PDF already on the device; Drift copies it into the **library** and opens it for reading.
_Avoid_: Upload, download, sync (there is no server).

**Library**:
The in-app list of imported **books**; the only place to add or remove titles.
_Avoid_: Shelf (informal), catalog, store.

**Book**:
One imported PDF in the library, with a saved reading position.
_Avoid_: File, document (too generic).

**Resume**:
Reopening the app continues the last **book** at the last reading position without showing the library first.
_Avoid_: Restore, sync position.

**Book artifacts**:
On-disk files for one **book** in the **library** sandbox — PDF copy, manifest, pagination cache.
_Avoid_: File bundle (too vague), document package.

## Example dialogue

**Dev:** How do I get a PDF from my Mac Downloads into Drift?

**Expert:** You don’t upload to Drift — you **import** from Files. Put the PDF on the phone (or simulator) first, then tap **+** in the **library** and select it. Drift copies it; your original in Downloads stays put.

## v1 scope (product)

- Born-digital text novels; hybrid fallback for image-only pages
- Local **import** only; copy on import; remove deletes the app copy only
- Fixed typography; paginated reading; vertical swipe to turn pages; tap anywhere for **Library** overlay; **resume** on launch
- Out of scope: highlights, search, cloud, Android
