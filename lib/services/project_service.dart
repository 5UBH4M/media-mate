import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../features/collage_editor/models/collage_project.dart';

class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  // Web fallback in-memory storage
  final Map<String, String> _webStorage = {};

  Future<String> _getProjectsDirectoryPath() async {
    if (kIsWeb) return '';
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/media_mate_projects';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<void> saveProject(CollageProject project) async {
    final updatedProject = project.copyWith(updatedAt: DateTime.now());
    final jsonStr = jsonEncode(updatedProject.toJson());

    if (kIsWeb) {
      _webStorage[project.id] = jsonStr;
      return;
    }

    try {
      final dirPath = await _getProjectsDirectoryPath();
      final file = File('$dirPath/${project.id}.json');
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving project: $e');
    }
  }

  Future<List<CollageProject>> getAllProjects() async {
    final List<CollageProject> projects = [];

    if (kIsWeb) {
      for (final jsonStr in _webStorage.values) {
        try {
          projects.add(CollageProject.fromJson(jsonDecode(jsonStr)));
        } catch (e) {
          debugPrint('Error decoding web project: $e');
        }
      }
      // Sort by updatedAt descending
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    }

    try {
      final dirPath = await _getProjectsDirectoryPath();
      final dir = Directory(dirPath);
      final List<FileSystemEntity> files = await dir.list().toList();

      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final jsonStr = await file.readAsString();
            final project = CollageProject.fromJson(jsonDecode(jsonStr));
            projects.add(project);
          } catch (e) {
            debugPrint('Error reading project file ${file.path}: $e');
          }
        }
      }
      // Sort by updatedAt descending
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error listing projects: $e');
    }

    return projects;
  }

  Future<CollageProject?> getProjectById(String id) async {
    if (kIsWeb) {
      final jsonStr = _webStorage[id];
      if (jsonStr != null) {
        return CollageProject.fromJson(jsonDecode(jsonStr));
      }
      return null;
    }

    try {
      final dirPath = await _getProjectsDirectoryPath();
      final file = File('$dirPath/$id.json');
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        return CollageProject.fromJson(jsonDecode(jsonStr));
      }
    } catch (e) {
      debugPrint('Error reading project: $e');
    }
    return null;
  }

  Future<void> deleteProject(String id) async {
    if (kIsWeb) {
      _webStorage.remove(id);
      return;
    }

    try {
      final dirPath = await _getProjectsDirectoryPath();
      final file = File('$dirPath/$id.json');
      if (await file.exists()) {
        await file.delete();
      }
      final thumbFile = File('$dirPath/thumbnails/thumb_$id.png');
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting project: $e');
    }
  }
}
