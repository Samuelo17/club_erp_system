class Category {
  final String id;
  final String name;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    this.isActive = true,
  });
}