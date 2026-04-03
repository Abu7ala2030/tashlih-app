import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker_public_info.dart';

class WorkerLookupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, WorkerPublicInfo>> getWorkersByIds(List<String> workerIds) async {
    final ids = workerIds.where((e) => e.trim().isNotEmpty).toSet().toList();

    if (ids.isEmpty) return {};

    final Map<String, WorkerPublicInfo> result = {};

    // Firestore whereIn حدّه عادة 10 أو أكثر حسب الإصدار/البيئة
    // لذلك نقسمها batches احتياطياً
    const int chunkSize = 10;

    for (int i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.skip(i).take(chunkSize).toList();

      final snapshot = await _firestore
          .collection('users') // <- غيّرها إلى workers إذا مشروعك يستخدم workers
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        result[doc.id] = WorkerPublicInfo.fromMap(doc.id, doc.data());
      }
    }

    return result;
  }
}