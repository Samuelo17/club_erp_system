class Product {
  final String id;
  final String categoryId;
  final String name;
  final double currentPrice;
  final bool isActive;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.currentPrice,
    this.isActive = true,
  });
}