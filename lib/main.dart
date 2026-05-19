import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

void main() {
  runApp(const MyApp());
}

class Flashcard {
  String frente;
  String verso;

  Flashcard({
    required this.frente,
    required this.verso,
  });
}

class PdfDocumentItem {
  final PlatformFile file;
  String? thumbnailPath;
  int ultimaPagina;

  PdfDocumentItem({
    required this.file,
    this.thumbnailPath,
    this.ultimaPagina = 1,
  });
}

class PdfGroup {
  String nome;
  List<PdfDocumentItem> pdfs;
  List<Flashcard> flashcards;

  PdfGroup({
    required this.nome,
    required this.pdfs,
    required this.flashcards,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leitor PDF',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<PdfGroup> grupos = [];

  Future<void> criarGrupo() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Novo Grupo'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Nome do grupo',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    grupos.add(
                      PdfGroup(
                        nome: controller.text.trim(),
                        pdfs: [],
                        flashcards: [],
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  void abrirGrupo(PdfGroup grupo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrupoPage(grupo: grupo),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('memolingua')),
      body: grupos.isEmpty
          ? const Center(child: Text('Nenhum grupo criado'))
          : ListView.builder(
              itemCount: grupos.length,
              itemBuilder: (context, index) {
                final grupo = grupos[index];
                return ListTile(
                  title: Text(grupo.nome),
                  subtitle: Text('${grupo.flashcards.length} palavras'),
                  onTap: () => abrirGrupo(grupo),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: criarGrupo,
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }
}

class GrupoPage extends StatefulWidget {
  final PdfGroup grupo;
  const GrupoPage({super.key, required this.grupo});

  @override
  State<GrupoPage> createState() => _GrupoPageState();
}

class _GrupoPageState extends State<GrupoPage> {
  Future<String?> gerarThumbnail(String pdfPath, int pagina) async {
    try {
      final document = await pdfx.PdfDocument.openFile(pdfPath);
      final page = await document.getPage(pagina);
      final pageImage = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      await page.close();
      await document.close();

      if (pageImage != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = '${pdfPath.hashCode}_page_$pagina.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(pageImage.bytes);
        return file.path;
      }
    } catch (e) {
      debugPrint("Erro ao gerar miniatura: $e");
    }
    return null;
  }

  Future<void> adicionarPdfAoGrupo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.first.path != null) {
      final novoPdf = PdfDocumentItem(file: result.files.first);
      
      setState(() {
        widget.grupo.pdfs.add(novoPdf);
      });

      final thumbPath = await gerarThumbnail(novoPdf.file.path!, 1);
      if (thumbPath != null) {
        setState(() {
          novoPdf.thumbnailPath = thumbPath;
        });
      }
    }
  }

  void abrirPdf(BuildContext context, PdfDocumentItem pdfItem) async {
    final ultimaPaginaLida = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          pdfItem: pdfItem,
          grupo: widget.grupo, // Devolvido o grupo para o leitor
        ),
      ),
    );

    if (ultimaPaginaLida != null && ultimaPaginaLida != pdfItem.ultimaPagina) {
      pdfItem.ultimaPagina = ultimaPaginaLida;
      final novoThumb = await gerarThumbnail(pdfItem.file.path!, ultimaPaginaLida);
      setState(() {
        pdfItem.thumbnailPath = novoThumb;
      });
    }
  }

  void abrirFlashcards() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardsPage(grupo: widget.grupo),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo.nome),
        actions: [
          IconButton(
            onPressed: abrirFlashcards,
            icon: const Icon(Icons.style),
          ),
        ],
      ),
      body: widget.grupo.pdfs.isEmpty
          ? const Center(child: Text('Nenhum PDF neste grupo'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: widget.grupo.pdfs.length,
              itemBuilder: (context, index) {
                final pdfItem = widget.grupo.pdfs[index];

                return GestureDetector(
                  onTap: () => abrirPdf(context, pdfItem),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: pdfItem.thumbnailPath != null
                              ? Image.file(
                                  File(pdfItem.thumbnailPath!),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.picture_as_pdf,
                                    size: 50,
                                    color: Colors.redAccent,
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            pdfItem.file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: adicionarPdfAoGrupo,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class FlashcardsPage extends StatelessWidget {
  final PdfGroup grupo;
  const FlashcardsPage({super.key, required this.grupo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulário')),
      body: grupo.flashcards.isEmpty
          ? const Center(child: Text('Nenhuma palavra adicionada'))
          : ListView.builder(
              itemCount: grupo.flashcards.length,
              itemBuilder: (context, index) {
                final flashcard = grupo.flashcards[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(flashcard.frente),
                    subtitle: Text(flashcard.verso),
                  ),
                );
              },
            ),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  final PdfDocumentItem pdfItem;
  final PdfGroup grupo; // Adicionado de volta aqui

  const PdfViewerPage({
    super.key, 
    required this.pdfItem,
    required this.grupo, // Adicionado de volta aqui
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  OverlayEntry? overlayEntry;
  late PdfViewerController _pdfViewerController;
  int _paginaAtual = 1;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _paginaAtual = widget.pdfItem.ultimaPagina;
  }

  void mostrarOverlay(BuildContext context, String textoSelecionado) {
    removerOverlay();

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  textoSelecionado,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // Restaurada a lógica original de adição de palavras
                    widget.grupo.flashcards.add(
                      Flashcard(
                        frente: textoSelecionado,
                        verso: "verso",
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Palavra adicionada")),
                    );
                    removerOverlay();
                  },
                  child: const Text("Adicionar ao Vocabulário"),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  void removerOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  @override
  void dispose() {
    removerOverlay();
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _paginaAtual);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.pdfItem.file.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _paginaAtual),
          ),
        ),
        body: SfPdfViewer.file(
          File(widget.pdfItem.file.path!),
          controller: _pdfViewerController,
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            if (widget.pdfItem.ultimaPagina > 1) {
              _pdfViewerController.jumpToPage(widget.pdfItem.ultimaPagina);
            }
          },
          onPageChanged: (PdfPageChangedDetails details) {
            _paginaAtual = details.newPageNumber;
          },
          onTextSelectionChanged: (details) {
            if (details.selectedText != null && details.selectedText!.isNotEmpty) {
              mostrarOverlay(context, details.selectedText!);
            } else {
              removerOverlay();
            }
          },
        ),
      ),
    );
  }
}