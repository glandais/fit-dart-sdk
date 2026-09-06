// The browser APIs Flutter itself does not wrap: choosing a file, dropping one
// onto the page, and saving the JSON. Web-only, deliberately — this app is the
// GitHub Pages demo and builds for no other platform.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A file the user handed to the page. Its bytes never leave it.
class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Opens the file dialog and reads what comes back, or null if the user closed
/// it without choosing.
Future<PickedFile?> chooseFitFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.fit';

  final chosen = Completer<PickedFile?>();
  input.onchange = ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      chosen.complete(null);
    } else {
      _read(file).then(chosen.complete);
    }
  }).toJS;
  // Without this a cancelled dialog would leave the caller waiting forever.
  input.oncancel = ((web.Event _) {
    if (!chosen.isCompleted) chosen.complete(null);
  }).toJS;

  input.click();
  return chosen.future;
}

/// Watches the whole page for a dropped file.
///
/// On the document rather than on a widget: Flutter paints into a canvas, so
/// there is no element under the drop zone to attach this to, and a file
/// dropped anywhere on the page is meant for the one thing the page does.
void listenForDroppedFiles({
  required void Function(bool over) onDragOver,
  required void Function(PickedFile file) onFile,
}) {
  final document = web.document;

  document.addEventListener(
    'dragover',
    ((web.Event event) {
      // Without preventDefault the browser navigates to the file instead.
      event.preventDefault();
      onDragOver(true);
    }).toJS,
  );
  document.addEventListener(
    'dragleave',
    ((web.Event _) => onDragOver(false)).toJS,
  );
  document.addEventListener(
    'drop',
    ((web.Event event) {
      event.preventDefault();
      onDragOver(false);
      final file = (event as web.DragEvent).dataTransfer?.files.item(0);
      if (file != null) {
        _read(file).then((picked) {
          if (picked != null) onFile(picked);
        });
      }
    }).toJS,
  );
}

/// Hands [content] to the browser as a download named [filename].
void saveTextFile(String filename, String content, String mimeType) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  link.click();
  web.URL.revokeObjectURL(url);
}

Future<PickedFile?> _read(web.File file) async {
  final buffer = await file.arrayBuffer().toDart;
  return PickedFile(file.name, buffer.toDart.asUint8List());
}

/// Opens [url] in another tab.
///
/// `noopener` so the new page cannot reach back through `window.opener`.
void openUrl(String url) => web.window.open(url, '_blank', 'noopener');
