import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

// ==========================================
// MODELOS DE DADOS COM SERIALIZAÇÃO JSON
// ==========================================

class Flashcard {
  String frente;
  String verso;
  int repetitions;
  int interval;
  double easeFactor;
  DateTime nextReview;

  Flashcard({
    required this.frente,
    required this.verso,
    this.repetitions = 0,
    this.interval = 0,
    this.easeFactor = 2.5,
    DateTime? nextReview,
  }) : nextReview = nextReview ?? DateTime.now();

  // Converte o objeto para um formato que o JSON entende
  Map<String, dynamic> toMap() => {
    'frente': frente,
    'verso': verso,
    'repetitions': repetitions,
    'interval': interval,
    'easeFactor': easeFactor,
    'nextReview': nextReview.toIso8601String(),
  };

  // Recria o objeto a partir dos dados salvos no JSON
  factory Flashcard.fromMap(Map<String, dynamic> map) => Flashcard(
    frente: map['frente'],
    verso: map['verso'],
    repetitions: map['repetitions'] ?? 0,
    interval: map['interval'] ?? 0,
    easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
    nextReview: map['nextReview'] != null
        ? DateTime.parse(map['nextReview'])
        : DateTime.now(),
  );
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

  Map<String, dynamic> toMap() => {
    'filePath': file.path,
    'fileName': file.name,
    'fileSize': file.size,
    'thumbnailPath': thumbnailPath,
    'ultimaPagina': ultimaPagina,
  };

  factory PdfDocumentItem.fromMap(Map<String, dynamic> map) => PdfDocumentItem(
    file: PlatformFile(
      path: map['filePath'],
      name: map['fileName'],
      size: map['fileSize'] ?? 0,
    ),
    thumbnailPath: map['thumbnailPath'],
    ultimaPagina: map['ultimaPagina'] ?? 1,
  );
}

class PdfGroup {
  String nome;
  String lingua;
  List<PdfDocumentItem> pdfs;
  List<Flashcard> flashcards;

  PdfGroup({
    required this.nome,
    required this.lingua,
    required this.pdfs,
    required this.flashcards,
  });

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'lingua': lingua,
    'pdfs': pdfs.map((e) => e.toMap()).toList(),
    'flashcards': flashcards.map((e) => e.toMap()).toList(),
  };

  factory PdfGroup.fromMap(Map<String, dynamic> map) => PdfGroup(
    nome: map['nome'],
    lingua: map['lingua'] ?? 'en',
    pdfs: (map['pdfs'] as List? ?? [])
        .map((e) => PdfDocumentItem.fromMap(e))
        .toList(),
    flashcards: (map['flashcards'] as List? ?? [])
        .map((e) => Flashcard.fromMap(e))
        .toList(),
  );
}

// ==========================================
// GERENCIADOR DE PERSISTÊNCIA LOCAL
// ==========================================

class PersistenceManager {
  static Future<File> _getStorageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/memolingua_storage.json');
  }

  // Grava a lista completa de grupos no arquivo local
  static Future<void> salvarGrupos(List<PdfGroup> grupos) async {
    try {
      final file = await _getStorageFile();
      final jsonString = jsonEncode(grupos.map((g) => g.toMap()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint("Erro ao salvar dados locais: $e");
    }
  }

  // Lê o arquivo local e converte de volta para a lista estruturada
  static Future<List<PdfGroup>> carregarGrupos() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((json) => PdfGroup.fromMap(json)).toList();
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados locais: $e");
    }
    return [];
  }
}

// ==========================================
// INTERFACES E TELAS DO APLICATIVO
// ==========================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leitor PDF',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
  List<PdfGroup> grupos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    final dadosCarregados = await PersistenceManager.carregarGrupos();
    setState(() {
      grupos = dadosCarregados;
      _carregando = false;
    });
  }

  Future<void> _persistirEAtualizar() async {
    await PersistenceManager.salvarGrupos(grupos);
    setState(() {});
  }

  Future<void> criarGrupo() async {
    final controller = TextEditingController();
    String linguaSelecionada = 'en';

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Novo Grupo'),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Nome do grupo'),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: linguaSelecionada,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('Inglês')),
                  DropdownMenuItem(value: 'es', child: Text('Espanhol')),
                  DropdownMenuItem(value: 'fr', child: Text('Francês')),
                  DropdownMenuItem(value: 'de', child: Text('Alemão')),
                  DropdownMenuItem(value: 'pt', child: Text('Português')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    linguaSelecionada = value;
                  }
                },
                decoration: const InputDecoration(labelText: 'Idioma do grupo'),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),

            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  grupos.add(
                    PdfGroup(
                      nome: controller.text.trim(),
                      lingua: linguaSelecionada,
                      pdfs: [],
                      flashcards: [],
                    ),
                  );

                  Navigator.pop(context);
                  _persistirEAtualizar();
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
        builder: (_) => GrupoPage(
          grupo: grupo,
          onSave:
              _persistirEAtualizar, // Passa a função de salvamento como callback
        ),
      ),
    );
    _persistirEAtualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('memolingua')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : grupos.isEmpty
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
  final VoidCallback onSave; // Recebe o gatilho de persistência da HomePage

  const GrupoPage({super.key, required this.grupo, required this.onSave});

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
      widget.onSave();

      final thumbPath = await gerarThumbnail(novoPdf.file.path!, 1);
      if (thumbPath != null) {
        setState(() {
          novoPdf.thumbnailPath = thumbPath;
        });
        widget.onSave();
      }
    }
  }

  void abrirPdf(BuildContext context, PdfDocumentItem pdfItem) async {
    final ultimaPaginaLida = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          pdfItem: pdfItem,
          grupo: widget.grupo,
          onSave: widget.onSave,
        ),
      ),
    );

    if (ultimaPaginaLida != null) {
      if (ultimaPaginaLida != pdfItem.ultimaPagina) {
        pdfItem.ultimaPagina = ultimaPaginaLida;

        final novoThumb = await gerarThumbnail(
          pdfItem.file.path!,
          ultimaPaginaLida,
        );

        setState(() {
          pdfItem.thumbnailPath = novoThumb;
        });
      }

      // força atualização da tela do grupo
      setState(() {});

      widget.onSave();
    }
  }

  void abrirFlashcards() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FlashcardsPage(grupo: widget.grupo)),
    ).then((_) {
      widget.onSave();
      setState(() {});
    });
  }

  void iniciarRevisao(List<Flashcard> cardsParaRevisar) async {
    final concluido = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReviewPage(cards: cardsParaRevisar)),
    );

    if (concluido == true) {
      widget.onSave(); // Garante o salvamento após alterar os parâmetros SM-2
      setState(() {});
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Revisão concluída 🎉'),
          content: const Text(
            'Você revisou todos os cartões agendados por enquanto!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Excelente'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final cardsPendentes = widget.grupo.flashcards.where((card) {
      return card.nextReview.isBefore(agora);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo.nome),
        actions: [
          IconButton(onPressed: abrirFlashcards, icon: const Icon(Icons.style)),
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
      bottomNavigationBar: cardsPendentes.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  12.0,
                  0,
                  12.0,
                  12.0,
                ), // Ajustado o padding superior para 0
                child: ElevatedButton.icon(
                  onPressed: () => iniciarRevisao(cardsPendentes),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.bolt),
                  label: Text(
                    'Revisar Vocabulário (${cardsPendentes.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          : null,
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
                final agora = DateTime.now();
                final bool pendente = flashcard.nextReview.isBefore(agora);

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(flashcard.frente),
                    subtitle: Text(flashcard.verso),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pendente ? Colors.red[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pendente ? 'Pendente' : 'Revisado',
                        style: TextStyle(
                          color: pendente ? Colors.red[800] : Colors.green[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  final PdfDocumentItem pdfItem;
  final PdfGroup grupo;
  final VoidCallback onSave;

  const PdfViewerPage({
    super.key,
    required this.pdfItem,
    required this.grupo,
    required this.onSave,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  OverlayEntry? overlayEntry;
  late PdfViewerController _pdfViewerController;
  int _paginaAtual = 1;

  //função para traduzir o texto e tals né
  Future<String> traduzirTexto(String textoOriginal) async {
    final url = Uri.parse("http://10.0.2.2:5000/translate");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "q": textoOriginal,
          "source": "auto",
          "target": "pt",
          "format": "text",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translatedText'] ?? 'Sem resposta da tradução';
      } else {
        return "Erro na tradução: ${response.body}";
      }
    } catch (e) {
      return "Erro de conexão: $e";
    }
  }

  Future<void> mostrarOverlay(
    BuildContext context,
    String textoSelecionado,
  ) async {
    removerOverlay();

    // Estado reativo da tradução
    final traducaoNotifier = ValueNotifier<String>('Traduzindo...');

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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Parte reativa
                ValueListenableBuilder<String>(
                  valueListenable: traducaoNotifier,
                  builder: (context, traducao, child) {
                    return Text(
                      traducao,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () async {
                    final traducaoAtual = traducaoNotifier.value;

                    widget.grupo.flashcards.add(
                      Flashcard(frente: textoSelecionado, verso: traducaoAtual),
                    );

                    widget.onSave();

                    _pdfViewerController.clearSelection();

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

    // Mostra IMEDIATAMENTE
    Overlay.of(context).insert(overlayEntry!);

    // Tradução acontece em paralelo
    final traducao = await traduzirTexto(textoSelecionado);

    // Atualiza o overlay quando chegar
    traducaoNotifier.value = traducao;
  }

  void removerOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _paginaAtual = widget.pdfItem.ultimaPagina;
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

          canShowTextSelectionMenu: false,
          enableTextSelection: true,
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            if (widget.pdfItem.ultimaPagina > 1) {
              _pdfViewerController.jumpToPage(widget.pdfItem.ultimaPagina);
            }
          },
          onPageChanged: (PdfPageChangedDetails details) {
            _paginaAtual = details.newPageNumber;
          },
          onTextSelectionChanged: (details) {
            if (details.selectedText != null &&
                details.selectedText!.isNotEmpty) {
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

class ReviewPage extends StatefulWidget {
  final List<Flashcard> cards;
  const ReviewPage({super.key, required this.cards});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _currentIndex = 0;
  bool _mostrarVerso = false;

  void _processarResposta(int quality) {
    final card = widget.cards[_currentIndex];

    // Mantida sua exata lógica original do SM-2 Puro do primeiro prompt
    if (quality < 3) {
      card.repetitions = 0;
      card.interval = 1;
    } else {
      if (card.repetitions == 0) {
        card.interval = 1;
      } else if (card.repetitions == 1) {
        card.interval = 6;
      } else {
        card.interval = (card.interval * card.easeFactor).round();
      }
      card.repetitions += 1;
    }

    card.easeFactor =
        card.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (card.easeFactor < 1.3) {
      card.easeFactor = 1.3;
    }

    card.nextReview = DateTime.now().add(Duration(days: card.interval));

    if (_currentIndex < widget.cards.length - 1) {
      setState(() {
        _currentIndex++;
        _mostrarVerso = false;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  String _previewIntervalo(int quality) {
    final card = widget.cards[_currentIndex];
    int proximoIntervalo;

    if (quality < 3) {
      proximoIntervalo = 1;
    } else {
      if (card.repetitions == 0) {
        proximoIntervalo = 1;
      } else if (card.repetitions == 1) {
        proximoIntervalo = 6;
      } else {
        proximoIntervalo = (card.interval * card.easeFactor).round();
      }
    }

    return proximoIntervalo == 1 ? '1 dia' : '$proximoIntervalo dias';
  }

  @override
  Widget build(BuildContext context) {
    final cardAtual = widget.cards[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Revisando (${_currentIndex + 1}/${widget.cards.length})'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      // O SafeArea aqui impede que os botões fiquem embaixo da navegação do Android
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'FRENTE',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cardAtual.frente,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_mostrarVerso) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(),
                          ),
                          const Text(
                            'VERSO',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cardAtual.verso,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!_mostrarVerso)
                ElevatedButton(
                  onPressed: () => setState(() => _mostrarVerso = true),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Mostrar Significado',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        _botaoGrade(
                          label: 'Tentar novamente',
                          color: Colors.red,
                          intervaloText: _previewIntervalo(1),
                          onPressed: () => _processarResposta(1),
                        ),
                        const SizedBox(width: 8),
                        _botaoGrade(
                          label: 'Difícil',
                          color: Colors.orange,
                          intervaloText: _previewIntervalo(3),
                          onPressed: () => _processarResposta(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _botaoGrade(
                          label: 'Fácil',
                          color: Colors.green,
                          intervaloText: _previewIntervalo(4),
                          onPressed: () => _processarResposta(4),
                        ),
                        const SizedBox(width: 8),
                        _botaoGrade(
                          label: 'Muito fácil',
                          color: Colors.teal,
                          intervaloText: _previewIntervalo(5),
                          onPressed: () => _processarResposta(5),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoGrade({
    required String label,
    required Color color,
    required String intervaloText,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              intervaloText,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
