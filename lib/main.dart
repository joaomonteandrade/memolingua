import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const MyApp());
}

class PdfGroup {
  String nome;
  List<PlatformFile> pdfs;

  PdfGroup({
    required this.nome,
    required this.pdfs,
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

  Future<void> adicionarPdfAoGrupo(PdfGroup grupo) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        grupo.pdfs.add(result.files.first);
      });
    }
  }

  void abrirGrupo(PdfGroup grupo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrupoPage(grupo: grupo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos de PDFs'),
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
                  leading: const Icon(Icons.folder),
                  title: Text(grupo.nome),
                  subtitle: Text(
                    '${grupo.pdfs.length} PDFs',
                  ),
                  onTap: () => abrirGrupo(grupo),

                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => adicionarPdfAoGrupo(grupo),
                  ),
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

class GrupoPage extends StatelessWidget {
  final PdfGroup grupo;

  const GrupoPage({
    super.key,
    required this.grupo,
  });

  void abrirPdf(BuildContext context, PlatformFile pdf) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(pdf: pdf),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(grupo.nome),
      ),
      body: grupo.pdfs.isEmpty
          ? const Center(
              child: Text('Nenhum PDF neste grupo'),
            )
          : ListView.builder(
              itemCount: grupo.pdfs.length,
              itemBuilder: (context, index) {
                final pdf = grupo.pdfs[index];

                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(pdf.name),
                  onTap: () => abrirPdf(context, pdf),
                );
              },
            ),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  final PlatformFile pdf;

  const PdfViewerPage({
    super.key,
    required this.pdf,
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
                    print(
                      "Texto selecionado: $textoSelecionado",
                    );

                    removerOverlay();
                  },
                  child: const Text("Meu Botão"),
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