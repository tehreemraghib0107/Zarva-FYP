import 'package:flutter/material.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  final List<Map<String, dynamic>> categories = const [
    {'image': 'assets/2N.png', 'name': 'Necklace'},
    {'image': 'assets/2E.png', 'name': 'Earrings'},
    {'image': 'assets/3B.png', 'name': 'Bracelet'},
    {'image': 'assets/4R.png', 'name': 'Ring'},
    {'image': 'assets/5C.png', 'name': 'Choker'},
  ];

  final List<Map<String, dynamic>> products = const [
    {
      'image': 'assets/1L.png',
      'name': 'Locket',
      'price': 'PKR 1509',
      'rating': 4.9,
    },
    {
      'image': 'assets/2C.png',
      'name': 'Choker',
      'price': 'PKR 2500',
      'rating': 5.0,
    },
    {
      'image': 'assets/2N.png',
      'name': 'Beaded Necklace',
      'price': 'PKR 1800',
      'rating': 4.6,
    },
    {
      'image': 'assets/4B.png',
      'name': 'Flower Bracelet',
      'price': 'PKR 1099',
      'rating': 4.5,
    },
    {
      'image': 'assets/5B.png',
      'name': 'Black Bracelet',
      'price': 'PKR 1200',
      'rating': 4.7,
    },
    {
      'image': 'assets/6R.png',
      'name': 'Red Ring',
      'price': 'PKR 1405',
      'rating': 4.8,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1C2D),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1C2D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Search',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.tune, color: Colors.white),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 CATEGORY HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('See All', style: TextStyle(color: Colors.white70)),
              ],
            ),

            const SizedBox(height: 14),

            // 🔹 CATEGORY ICONS
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return Column(
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            categories[index]['image'],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        categories[index]['name'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 🔥 PRODUCT GRID (FIXED OVERFLOW)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (context, index) {
                final product = products[index];

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🖼 EVEN IMAGE SIZE
                      AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(
                          product['image'],
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ✅ FLEXIBLE CONTENT (NO OVERFLOW)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              product['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            Text(
                              product['price'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(product['rating'].toString()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
