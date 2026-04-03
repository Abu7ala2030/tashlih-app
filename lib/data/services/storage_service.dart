import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadVehicleImage({
    required File file,
    required String folderName,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('vehicles').child(folderName).child(fileName);

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
