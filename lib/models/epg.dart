class EpgProgram {
  const EpgProgram({
    required this.title,
    required this.start,
    required this.end,
    this.desc,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String? desc;

  bool isOnAt(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  factory EpgProgram.fromJson(Map<String, dynamic> j) {
    DateTime parse(dynamic v) {
      if (v is int) {
        // 秒或毫秒
        if (v > 100000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v);
        }
        return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      }
      return DateTime.tryParse('$v') ?? DateTime.now();
    }

    return EpgProgram(
      title: '${j['title'] ?? j['name'] ?? '节目'}',
      start: parse(j['start'] ?? j['startTime']),
      end: parse(j['end'] ?? j['endTime'] ?? j['stop']),
      desc: j['desc']?.toString() ?? j['description']?.toString(),
    );
  }
}
