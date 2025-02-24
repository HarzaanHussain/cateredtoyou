import 'package:flutter/material.dart';
import 'package:cateredtoyou/services/department_service.dart';

/// A provider that caches department data and provides reactive updates
/// to the UI when departments change.
class DepartmentProvider extends ChangeNotifier {
  List<String> _departments = [];
  bool _isLoading = true;
  final DepartmentService _departmentService;

  DepartmentProvider(this._departmentService) {
    loadDepartments(); // Load departments on initialization
  }

  List<String> get departments => _departments;
  bool get isLoading => _isLoading;

  Future<void> loadDepartments() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('Loading departments...');
      final deptStream = _departmentService.getDepartments();
      final deptList = await deptStream.first;
      _departments = deptList.map((dept) => dept['name'] as String).toList();

      _departmentService.getDepartments().listen((deptList) {
        final newDepts = deptList.map((dept) => dept['name'] as String).toList();
        if (!_listsEqual(_departments, newDepts)) {
          _departments = newDepts;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Error loading departments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  /// Helper method to check if two lists contain the same elements in the same order
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}