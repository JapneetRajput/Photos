import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
        ),
        colorScheme: ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.blueAccent,
          background: Colors.grey[900]!,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final BehaviorSubject<List<Medium?>> _mediaSubject =
      BehaviorSubject<List<Medium?>>();
  final Map<String, Uint8List> _thumbnails = {};
  final Set<Medium> _selectedMedia = {};
  List<String> _uploadedPhotos = [];
  String _errorMessage = '';
  String _uploadStatus = '';
  bool _isLoading = true;
  bool _isUploading = false;
  bool _selectionMode = false;
  int _currentPage = 0;
  static const int _initialItems = 600;
  static const int _itemsPerPage = 300;
  final ScrollController _scrollController = ScrollController();
  List<Medium?> _mediaList = List.generate(_initialItems, (_) => null);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    var statuses = await [
      Permission.photos,
      Permission.mediaLibrary,
      Permission.manageExternalStorage,
    ].request();

    if (statuses[Permission.photos]!.isGranted &&
        statuses[Permission.mediaLibrary]!.isGranted &&
        statuses[Permission.manageExternalStorage]!.isGranted) {
      await _fetchUploadedPhotos();
      await _fetchMedia();
    } else if (statuses[Permission.photos]!.isPermanentlyDenied ||
        statuses[Permission.mediaLibrary]!.isPermanentlyDenied ||
        statuses[Permission.manageExternalStorage]!.isPermanentlyDenied) {
      setState(() {
        _errorMessage =
            'Necessary permissions permanently denied. Please enable them from settings.';
        _isLoading = false;
      });
      openAppSettings();
    } else {
      setState(() {
        _errorMessage = 'Necessary permissions not granted';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUploadedPhotos() async {
    try {
      var url = Uri.parse(
          'https://enabled-griffon-known.ngrok-free.app/uploaded-photos');
      var headers = {
        'Authorization': 'arjunrajput',
      };
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          _uploadedPhotos = List<String>.from(json.decode(response.body));
        });
      } else {
        throw Exception('Failed to load uploaded photos');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching uploaded photos: $e';
      });
    }
  }

  Future<void> _fetchMedia() async {
    try {
      List<Album> albums =
          await PhotoGallery.listAlbums(mediumType: MediumType.image);
      if (albums.isEmpty) {
        setState(() {
          _errorMessage = 'No albums found';
          _isLoading = false;
        });
        return;
      }
      Album album = albums.first;
      MediaPage mediaPage = await album.listMedia();
      int start = _currentPage * _itemsPerPage;
      int end = start + _itemsPerPage;
      end = end > mediaPage.items.length ? mediaPage.items.length : end;

      if (end > _mediaList.length) {
        _mediaList.addAll(List.generate(end - _mediaList.length, (_) => null));
      }

      for (int i = start; i < end; i++) {
        var medium = mediaPage.items[i];
        _mediaList[i] = medium;
        _mediaSubject.add(List<Medium?>.from(_mediaList));
        _loadThumbnail(medium);
      }

      setState(() {
        _isLoading = false;
        _currentPage++;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching media: $e';
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.08) {
      _fetchMedia();
    }
  }

  Future<void> _loadThumbnail(Medium medium) async {
    if (!_thumbnails.containsKey(medium.id)) {
      try {
        final bytes = await medium.getThumbnail(width: 200, height: 200);
        setState(() {
          _thumbnails[medium.id] = Uint8List.fromList(bytes);
        });
      } catch (e) {}
    }
  }

  void _toggleSelection(Medium medium) {
    setState(() {
      if (_selectedMedia.contains(medium)) {
        _selectedMedia.remove(medium);
      } else {
        _selectedMedia.add(medium);
      }
      if (_selectedMedia.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _onLongPress(Medium medium) {
    setState(() {
      _selectionMode = true;
      _toggleSelection(medium);
    });
  }

  void _selectAll() {
    setState(() {
      _selectedMedia.clear();
      _selectedMedia
          .addAll(_mediaList.where((medium) => medium != null).cast<Medium>());
      _selectionMode = true;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedMedia.clear();
      _selectionMode = false;
    });
  }

  Future<void> _uploadPhotos() async {
    TextEditingController folderNameController = TextEditingController();

// Show dialog box for folder name input
    String? folderName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Folder Name'),
          content: TextField(
            controller: folderNameController,
            decoration: InputDecoration(hintText: 'Folder Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Close dialog without returning data
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(folderNameController.text.trim());
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading 0/${_selectedMedia.length} photos...';
    });

    try {
      int totalMedia = _selectedMedia.length;
      int batchSize = 50;
      int uploadedCount = 0;

      List<List<Medium>> batches = [];
      for (int i = 0; i < totalMedia; i += batchSize) {
        int end = (i + batchSize > totalMedia) ? totalMedia : i + batchSize;
        batches.add(_selectedMedia.toList().sublist(i, end));
      }

      for (var batch in batches) {
        List<http.MultipartFile> files = [];

        for (var medium in batch) {
          File? file = await medium.getFile();
          if (file != null) {
            Uint8List bytes = await file.readAsBytes();
            files.add(http.MultipartFile.fromBytes(
              'photos',
              bytes,
              filename: path.basename(file.path),
            ));
          }
          uploadedCount++;
          setState(() {
            _uploadStatus = 'Uploading $uploadedCount/$totalMedia photos...';
          });
        }

        var request = http.MultipartRequest(
            'POST',
            Uri.parse(
                'https://enabled-griffon-known.ngrok-free.app/upload-multiple'));
        request.headers['Authorization'] = 'arjunrajput';
        request.files.addAll(files);
        request.fields['folderName'] = folderName!;

        var response = await request.send();

        if (response.statusCode != 200) {
          setState(() {
            _uploadStatus = 'Failed to upload photos.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload photos.')));
          return;
        }
      }

      setState(() {
        _selectedMedia.forEach((medium) {
          if (!_uploadedPhotos.contains(medium.filename)) {
            _uploadedPhotos.add(medium.filename!);
          }
        });
        _selectedMedia.clear();
        _selectionMode = false;
        _uploadStatus = 'Photos uploaded successfully.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photos uploaded successfully.')));
    } catch (e) {
      setState(() {
        _uploadStatus = 'Error: $e';
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<int> _calculateTotalSizeOfUploadedPhotos() async {
    int totalSize = 0;
    for (String uploadedPhoto in _uploadedPhotos) {
      Medium? medium = _mediaList.firstWhere(
        (medium) => medium?.filename == uploadedPhoto,
        orElse: () => null,
      );
      if (medium != null) {
        File? file = await medium.getFile();
        if (file != null) {
          totalSize += await file.length();
        }
      }
    }
    return totalSize;
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes == 0) return "0 B";
    const k = 1024;
    const dm = 1;
    const sizes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(k)).floor();
    return ((bytes / pow(k, i)).toStringAsFixed(dm)) + ' ' + sizes[i];
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    int totalSize = await _calculateTotalSizeOfUploadedPhotos();
    String totalSizeFormatted = _formatBytes(totalSize, 2);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete the uploaded photos from your device? This will free up $totalSizeFormatted of storage.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUploadedPhotos();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUploadedPhotos() async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Deleting 0/${_uploadedPhotos.length} photos...';
    });

    try {
      if (_uploadedPhotos.isEmpty) {
        setState(() {
          _uploadStatus = 'No uploaded photos to delete.';
          _isUploading = false;
        });
        return;
      }

      int totalMedia = _uploadedPhotos.length;
      int deletedCount = 0;

      for (String uploadedPhoto in _uploadedPhotos) {
        Medium? medium = _mediaList.firstWhere(
          (medium) => medium?.filename == uploadedPhoto,
          orElse: () => null,
        );

        if (medium == null) {
          continue;
        }

        File? file = await medium.getFile();
        if (file != null && await file.exists()) {
          await file.delete();
        }

        deletedCount++;
        setState(() {
          _uploadStatus = 'Deleting $deletedCount/$totalMedia photos...';
        });
      }

      setState(() {
        _uploadStatus = 'Uploaded photos deleted successfully.';
        _isLoading = true;
        _mediaList = List.generate(_initialItems, (_) => null);
        _currentPage = 0;
        _uploadedPhotos.clear();
      });
      _fetchMedia();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded photos deleted successfully.')),
      );
    } catch (e) {
      setState(() {
        _uploadStatus = 'Error deleting photos: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting photos: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Photos'),
        actions: [
          _selectionMode
              ? IconButton(
                  icon: Icon(Icons.select_all),
                  onPressed: _selectAll,
                )
              : Container(),
          _selectionMode
              ? IconButton(
                  icon: Icon(Icons.cancel),
                  onPressed: _cancelSelection,
                )
              : Container(),
          IconButton(
            icon: Icon(Icons.upload),
            onPressed: _selectedMedia.isNotEmpty ? _uploadPhotos : null,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete uploaded photos') {
                _showDeleteConfirmationDialog(context);
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Delete Uploaded Photos'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice.toLowerCase(),
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
              : StreamBuilder<List<Medium?>>(
                  stream: _mediaSubject.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: TextStyle(color: Colors.white)),
                      );
                    }

                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    List<Medium?> mediaList = snapshot.data!;
                    return GridView.builder(
                      controller: _scrollController,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 1.25,
                        mainAxisSpacing: 1.25,
                      ),
                      itemCount: mediaList.length,
                      itemBuilder: (context, index) {
                        final medium = mediaList[index];
                        return GestureDetector(
                          key: ValueKey(medium?.id ?? index),
                          onTap: () => _selectionMode && medium != null
                              ? _toggleSelection(medium)
                              : null,
                          onLongPress: () =>
                              medium != null ? _onLongPress(medium) : null,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              medium != null &&
                                      _thumbnails.containsKey(medium.id)
                                  ? Image.memory(
                                      _thumbnails[medium.id]!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[700],
                                      child: Shimmer.fromColors(
                                        baseColor: Colors.grey[700]!,
                                        highlightColor: Colors.grey[500]!,
                                        period: Duration(milliseconds: 150),
                                        child: Container(),
                                      ),
                                    ),
                              if (medium != null &&
                                  _selectedMedia.contains(medium))
                                Container(
                                  color: Colors.black54,
                                  child: Icon(Icons.check, color: Colors.white),
                                ),
                              if (medium != null &&
                                  medium.filename != null &&
                                  _uploadedPhotos.contains(medium.filename))
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Icon(
                                    Icons.cloud_done,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
          if (_isUploading)
            Center(
              child: Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4.0,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      _uploadStatus,
                      style: TextStyle(fontSize: 16.0, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
