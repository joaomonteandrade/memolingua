import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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

class PdfGroup {
  String nome;
  List<PlatformFile> pdfs;
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
      appBar: AppBar(
        title: const Text('memolingua'),
      ),
      body: grupos.isEmpty
          ? const Center(
              child: Text('Nenhum grupo criado'),
            )
          : ListView.builder(
              itemCount: grupos.length,
              itemBuilder: (context, index) {
                final grupo = grupos[index];

                return ListTile(
                  title: Text(grupo.nome),
                  subtitle: Text(
                    '${grupo.flashcards.length} flashcards',
                  ),
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

  const GrupoPage({
    super.key,
    required this.grupo,
  });

  @override
  State<GrupoPage> createState() => _GrupoPageState();
}

class _GrupoPageState extends State<GrupoPage> {
  Future<void> adicionarPdfAoGrupo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        widget.grupo.pdfs.add(result.files.first);
      });
    }
  }

  void abrirPdf(
    BuildContext context,
    PlatformFile pdf,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          pdf: pdf,
          grupo: widget.grupo,
        ),
      ),
    );
  }

  void abrirFlashcards() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardsPage(
          grupo: widget.grupo,
        ),
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
          ? const Center(
              child: Text('Nenhum PDF neste grupo'),
            )
          : ListView.builder(
              itemCount: widget.grupo.pdfs.length,
              itemBuilder: (context, index) {
                final pdf = widget.grupo.pdfs[index];

                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(pdf.name),
                  onTap: () => abrirPdf(context, pdf),
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

  const FlashcardsPage({
    super.key,
    required this.grupo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
      ),
      body: grupo.flashcards.isEmpty
          ? const Center(
              child: Text('Nenhum flashcard criado'),
            )
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
  final PlatformFile pdf;
  final PdfGroup grupo;

  const PdfViewerPage({
    super.key,
    required this.pdf,
    required this.grupo,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  OverlayEntry? overlayEntry;

  void mostrarOverlay(
    BuildContext context,
    String textoSelecionado,
  ) {
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: () {
                    widget.grupo.flashcards.add(
                      Flashcard(
                        frente: textoSelecionado,
                        verso: "verso",
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Flashcard criado",
                        ),
                      ),
                    );

                    removerOverlay();
                  },
                  child: const Text(
                    "Criar Flashcard",
                  ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdf.name),
      ),
      body: SfPdfViewer.file(
        File(widget.pdf.path!),
        onTextSelectionChanged: (details) {
          if (details.selectedText != null &&
              details.selectedText!.isNotEmpty) {
            mostrarOverlay(
              context,
              details.selectedText!,
            );
          } else {
            removerOverlay();
          }
        },
      ),
    );
  }
}