import 'package:flutter/material.dart';

class HomeProvider extends ChangeNotifier {
  List<Map<String, dynamic>> filteredVehicles = [];
  Map<String, dynamic>? selectedVehicle;

  String searchQuery = '';
  String selectedBrand = 'الكل';

  void setVehicles(List<Map<String, dynamic>> vehicles) {
    filteredVehicles = List<Map<String, dynamic>>.from(vehicles);
    notifyListeners();
  }

  void setSelectedVehicle(Map<String, dynamic> vehicle) {
    selectedVehicle = vehicle;
    notifyListeners();
  }

  void updateSearchQuery(String value, List<Map<String, dynamic>> allVehicles) {
    searchQuery = value;
    _applyFilters(allVehicles);
  }

  void selectBrand(String brand, List<Map<String, dynamic>> allVehicles) {
    selectedBrand = brand;
    _applyFilters(allVehicles);
  }

  void resetSearch(List<Map<String, dynamic>> allVehicles) {
    searchQuery = '';
    selectedBrand = 'الكل';
    filteredVehicles = List<Map<String, dynamic>>.from(allVehicles);
    notifyListeners();
  }

  void _applyFilters(List<Map<String, dynamic>> allVehicles) {
    filteredVehicles = allVehicles.where((vehicle) {
      final make = (vehicle['make'] ?? '').toString().toLowerCase();
      final model = (vehicle['model'] ?? '').toString().toLowerCase();
      final year = (vehicle['year'] ?? '').toString();
      final city = (vehicle['city'] ?? '').toString().toLowerCase();

      final matchesBrand = selectedBrand == 'الكل' ||
          make == selectedBrand.toLowerCase();

      final q = searchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          make.contains(q) ||
          model.contains(q) ||
          year.contains(q) ||
          city.contains(q);

      return matchesBrand && matchesQuery;
    }).toList();

    notifyListeners();
  }
}
