import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/ocr_service.dart';
import '../../core/models/vocab.dart';
import '../../core/database/vocab_repository.dart';
import 'translation_bottom_sheet.dart';

final selectedOcrTextProvider = StateProvider<String?>((ref) => null);

class MangaPageWidget extends ConsumerStatefulWidget {
  final String imageUrl;
  final String mangaTitle;

  const MangaPageWidget({super.key, required this.imageUrl, this.mangaTitle = 'Unknown Manga'});

  @override
  ConsumerState<MangaPageWidget> createState() => _MangaPageWidgetState();
}

class _MangaPageWidgetState extends ConsumerState<MangaPageWidget> {
  List<OcrResult>? _ocrResults;
  bool _isProcessing = false;
  ui.Image? _imageInfo;
  List<Vocab> _savedVocab = [];
  List<OcrResult> _selectedBlocks = [];
  PersistentBottomSheetController? _bottomSheetController;

  @override
  void initState() {
    super.initState();
    _loadSavedVocab();
  }

  Future<void> _loadSavedVocab() async {
    if (!mounted) return;
    final repo = ref.read(vocabRepositoryProvider);
    // Load ALL vocab globally so highlighting works across all decks
    final vocabs = await repo.getAllVocab();
    if (mounted) setState(() => _savedVocab = vocabs);
  }

  @override
  void dispose() {
    _removeBottomSheet();
    super.dispose();
  }

  void _removeBottomSheet() {
    _bottomSheetController?.close();
    _bottomSheetController = null;
    // Don't modify providers in dispose synchronously
  }

  void _updatePersistentBottomSheet() {
    if (_selectedBlocks.isEmpty) {
      _bottomSheetController?.close();
      _bottomSheetController = null;
      ref.read(selectedOcrTextProvider.notifier).state = null;
      return;
    }

    final sorted = _selectedBlocks.toList()
      ..sort((a, b) {
        if ((a.boundingBox.right - b.boundingBox.right).abs() < 50) {
          return a.boundingBox.top.compareTo(b.boundingBox.top);
        }
        return b.boundingBox.right.compareTo(a.boundingBox.right);
      });
    final combinedText = sorted.map((b) => b.text).join('');

    ref.read(selectedOcrTextProvider.notifier).state = combinedText;

    if (_bottomSheetController == null) {
      _bottomSheetController = Scaffold.of(context).showBottomSheet(
        (context) => Consumer(
          builder: (context, ref, _) {
            final text = ref.watch(selectedOcrTextProvider);
            if (text == null) return const SizedBox.shrink();
            return TranslationBottomSheet(text: text, mangaTitle: widget.mangaTitle);
          }
        ),
        backgroundColor: Colors.transparent,
      );
      
      _bottomSheetController!.closed.then((_) {
        if (mounted) {
          setState(() {
            _selectedBlocks.clear();
            _bottomSheetController = null;
            ref.read(selectedOcrTextProvider.notifier).state = null;
          });
          // Reload saved vocab so newly added words get highlighted
          _loadSavedVocab();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
         if (_selectedBlocks.isNotEmpty) {
            setState(() => _selectedBlocks.clear());
            _updatePersistentBottomSheet();
         }
      },
      child: Stack(
      alignment: Alignment.center,
      children: [
        // Display the manga page
        widget.imageUrl.startsWith('http')
          ? CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
              imageBuilder: (context, imageProvider) {
                // We need image dimensions to properly scale OCR boxes
                imageProvider.resolve(const ImageConfiguration()).addListener(
                  ImageStreamListener((info, _) {
                    if (mounted && _imageInfo == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                             _imageInfo = info.image;
                          });
                          if (_ocrResults == null && !_isProcessing) {
                             _runOcr();
                          }
                        }
                      });
                    }
                  }),
                );
                return Image(image: imageProvider, fit: BoxFit.contain);
              },
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final imageProvider = FileImage(File(widget.imageUrl));
                imageProvider.resolve(const ImageConfiguration()).addListener(
                  ImageStreamListener((info, _) {
                    if (mounted && _imageInfo == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                             _imageInfo = info.image;
                          });
                          if (_ocrResults == null && !_isProcessing) {
                             _runOcr();
                          }
                        }
                      });
                    }
                  }),
                );
                return Image(
                  image: imageProvider,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.white),
                );
              },
            ),



        // OCR Bounding Boxes
        if (_ocrResults != null && _imageInfo != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
              // Calculate scale and translation for bounding boxes relative to 
              // the actual displayed image within the Stack/AspectRatio
              double displayWidth = constraints.maxWidth;
              double displayHeight = constraints.maxHeight;
              
              double imageWidth = _imageInfo!.width.toDouble();
              double imageHeight = _imageInfo!.height.toDouble();

              // Image is fitted with BoxFit.contain
              double scale = displayWidth / imageWidth;
              if (imageHeight * scale > displayHeight) {
                scale = displayHeight / imageHeight;
              }

              double fittedWidth = imageWidth * scale;
              double fittedHeight = imageHeight * scale;

              double leftOffset = (displayWidth - fittedWidth) / 2;
              double topOffset = (displayHeight - fittedHeight) / 2;

              return Stack(
                children: _ocrResults!.map((result) {
                  final rect = result.boundingBox;
                  final mappedLeft = leftOffset + rect.left * scale;
                  final mappedTop = topOffset + rect.top * scale;
                  final mappedWidth = rect.width * scale;
                  final mappedHeight = rect.height * scale;

                  final isSaved = _savedVocab.any((v) => v.kana == result.text || v.kanji == result.text);
                  final isSelected = _selectedBlocks.contains(result);

                  return Positioned(
                    left: mappedLeft,
                    top: mappedTop,
                    width: mappedWidth,
                    height: mappedHeight,
                    child: GestureDetector(
                      onTap: () {
                         setState(() {
                            if (isSelected) {
                               _selectedBlocks.remove(result);
                            } else {
                               _selectedBlocks.add(result);
                            }
                            _updatePersistentBottomSheet();
                         });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                             ? Colors.blue.withAlpha(100)
                             : (isSaved ? Colors.yellow.withAlpha(76) : Colors.transparent),
                          border: Border.all(
                            color: isSelected
                               ? Colors.blue
                               : (isSaved ? Colors.red : Colors.transparent), 
                            width: isSelected ? 2.0 : 1.5
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    ),
    );
  }

  Future<void> _runOcr() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final service = ref.read(ocrServiceProvider);
      final results = await service.processImage(widget.imageUrl);
      setState(() {
        _ocrResults = results;
      });
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
         setState(() {
           _isProcessing = false;
         });
      }
    }
  }
}
