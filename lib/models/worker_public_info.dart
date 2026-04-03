class WorkerPublicInfo {
  final String id;
  final String name;
  final String tashlihName;

  const WorkerPublicInfo({
    required this.id,
    required this.name,
    required this.tashlihName,
  });

  factory WorkerPublicInfo.fromMap(String id, Map<String, dynamic> map) {
    return WorkerPublicInfo(
      id: id,
      name: (map['name'] ?? map['workerName'] ?? '').toString(),
      tashlihName: (map['tashlihName'] ?? map['scrapyardName'] ?? map['shopName'] ?? '').toString(),
    );
  }

  static const empty = WorkerPublicInfo(
    id: '',
    name: '',
    tashlihName: '',
  );
}