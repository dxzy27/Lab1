import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'article.dart';

class CacheService {
  static const String _articlesKey = 'cached_articles';
  static const String _lastFetchKey = 'last_fetch_time';
  static const Duration _cacheDuration = Duration(hours: 1); // Cache for 1 hour

  // Save articles to local storage
  Future<void> saveArticles(List<Article> articles) async {
    final prefs = await SharedPreferences.getInstance();
    final articlesJson = articles
        .map(
          (article) => {
            'title': article.title,
            'description': article.description,
            'urlToImage': article.urlToImage,
            'url': article.url,
          },
        )
        .toList();

    await prefs.setString(_articlesKey, jsonEncode(articlesJson));
    await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Load articles from local storage
  Future<List<Article>?> loadArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final articlesString = prefs.getString(_articlesKey);

    if (articlesString != null) {
      final articlesJson = jsonDecode(articlesString) as List;
      return articlesJson
          .map(
            (json) => Article(
              title: json['title'] ?? 'No Title',
              description: json['description'] ?? 'No Description',
              urlToImage:
                  json['urlToImage'] ?? 'https://via.placeholder.com/150',
              url: json['url'] ?? '',
            ),
          )
          .toList();
    }

    return null;
  }

  // Check if cache is still valid
  Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetch = prefs.getInt(_lastFetchKey);

    if (lastFetch == null) return false;

    final lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastFetch);
    final now = DateTime.now();

    return now.difference(lastFetchTime) < _cacheDuration;
  }

  // Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_articlesKey);
    await prefs.remove(_lastFetchKey);
  }
}
