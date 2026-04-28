import 'dart:convert';
import 'package:http/http.dart' as http;
import 'article.dart';
import 'cache_service.dart';

class NewsApiService {
  static const int defaultPageSize = 20;
  final String apiKey = '13f8bda718bf471da726a90a6198e9b2';
  final String baseUrl = 'https://newsapi.org/v2/';
  final CacheService _cacheService = CacheService();

  Future<List<Article>> fetchTopHeadlines({
    String country = 'us',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      // Try to fetch from API first, with a timeout to avoid long buffering.
      final String url =
          '${baseUrl}top-headlines?country=$country&page=$page&pageSize=$pageSize&apiKey=$apiKey';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> articlesJson = jsonData['articles'];
        final articles = articlesJson
            .map((jsonItem) => Article.fromJson(jsonItem))
            .toList();

        // Save to cache for offline use
        if (page == 1) {
          await _cacheService.saveArticles(articles);
        }

        return articles;
      } else {
        throw Exception('Failed to load news from API: ${response.statusCode}');
      }
    } catch (e) {
      print('API failed, loading from cache: $e');
      final cachedArticles = await _cacheService.loadArticles();

      if (cachedArticles != null && cachedArticles.isNotEmpty) {
        return cachedArticles;
      } else {
        throw Exception(
          'Failed to load news from API and no cached data available',
        );
      }
    }
  }

  // Method to check if we have cached data available
  Future<bool> hasCachedData() async {
    final cachedArticles = await _cacheService.loadArticles();
    return cachedArticles != null && cachedArticles.isNotEmpty;
  }

  // Load cached articles directly
  Future<List<Article>?> loadCachedArticles() async {
    return await _cacheService.loadArticles();
  }

  // Method to clear cache
  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }
}
