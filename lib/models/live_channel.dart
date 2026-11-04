class LiveChannel {
  const LiveChannel({
    required this.id,
    required this.name,
    required this.group,
    required this.url,
    this.logo,
  });

  final String id;
  final String name;
  final String group;
  final String url;
  final String? logo;
}
