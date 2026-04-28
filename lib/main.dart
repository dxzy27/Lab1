import 'package:flutter/material.dart';
import 'article.dart';
import 'news_api_service.dart';
import 'article_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  runApp(NewsApp());
}

class NewsApp extends StatefulWidget {
  const NewsApp({super.key});

  @override
  _NewsAppState createState() => _NewsAppState();
}

class _NewsAppState extends State<NewsApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'News App Lab',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      home: NewsHomePage(onThemeToggle: toggleTheme),
    );
  }
}

class NewsHomePage extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const NewsHomePage({super.key, required this.onThemeToggle});

  @override
  _NewsHomePageState createState() => _NewsHomePageState();
}

class _NewsHomePageState extends State<NewsHomePage> {
  final NewsApiService newsApiService = NewsApiService();
  late ScrollController _scrollController;

  List<Article> allArticles = [];
  List<Article> filteredArticles = [];
  int currentPage = 1;
  bool isLoadingMore = false;
  bool hasMoreArticles = true;
  bool isLoading = true;
  bool isOfflineMode = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialArticles();
  }

  Future<void> _loadInitialArticles() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      currentPage = 1;
      hasMoreArticles = true;
    });

    try {
      final articles = await newsApiService.fetchTopHeadlines(page: 1);
      setState(() {
        allArticles = articles;
        filteredArticles = articles;
        currentPage = 1;
        isLoadingMore = false;
        hasMoreArticles = articles.length == NewsApiService.defaultPageSize;
        isOfflineMode = false;
        errorMessage = null;
      });
    } catch (e) {
      final cachedArticles = await newsApiService.loadCachedArticles();
      if (cachedArticles != null && cachedArticles.isNotEmpty) {
        setState(() {
          allArticles = cachedArticles;
          filteredArticles = cachedArticles;
          currentPage = 1;
          isLoadingMore = false;
          hasMoreArticles = false;
          isOfflineMode = true;
          errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offline mode: Showing cached articles'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          errorMessage =
              'Unable to load articles. Please check your connection.';
        });
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // When user scrolls to 80% of the list, load more
    if (currentScroll >= (maxScroll * 0.8) &&
        !isLoadingMore &&
        hasMoreArticles) {
      _loadMoreArticles();
    }
  }

  Future<void> _loadMoreArticles() async {
    if (isLoadingMore || !hasMoreArticles || isOfflineMode) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      final newArticles = await newsApiService.fetchTopHeadlines(
        page: currentPage + 1,
      );

      setState(() {
        if (newArticles.isEmpty) {
          hasMoreArticles = false;
        } else {
          allArticles.addAll(newArticles);
          filteredArticles = allArticles;
          currentPage++;
          hasMoreArticles =
              newArticles.length == NewsApiService.defaultPageSize;
        }
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        isLoadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading more: $e')));
    }
  }

  void searchArticles(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredArticles = allArticles;
      } else {
        filteredArticles = allArticles
            .where(
              (article) =>
                  article.title.toLowerCase().contains(query.toLowerCase()) ||
                  article.description.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  Future<void> _refreshArticles() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final articles = await newsApiService.fetchTopHeadlines(page: 1);
      setState(() {
        allArticles = articles;
        filteredArticles = articles;
        currentPage = 1;
        isLoadingMore = false;
        hasMoreArticles = articles.length == NewsApiService.defaultPageSize;
        isOfflineMode = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Articles refreshed')));
    } catch (e) {
      final cachedArticles = await newsApiService.loadCachedArticles();
      if (cachedArticles != null && cachedArticles.isNotEmpty) {
        setState(() {
          allArticles = cachedArticles;
          filteredArticles = cachedArticles;
          currentPage = 1;
          isLoadingMore = false;
          hasMoreArticles = false;
          isOfflineMode = true;
          errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offline mode: Showing cached articles')),
        );
      } else {
        setState(() {
          errorMessage = 'Failed to refresh articles. Please try again.';
        });
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Top Headlines'),
            if (isOfflineMode) ...[
              SizedBox(width: 8),
              Icon(Icons.wifi_off, size: 16),
              SizedBox(width: 4),
              Text('(Offline)', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshArticles,
            tooltip: 'Refresh articles',
          ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: widget.onThemeToggle,
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadInitialArticles,
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: TextField(
                    onChanged: searchArticles,
                    decoration: InputDecoration(
                      hintText: "Search news...",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        filteredArticles.length +
                        (isLoadingMore || hasMoreArticles ? 1 : 0),
                    itemBuilder: (context, index) {
                      final isLoaderRow = index == filteredArticles.length;
                      if (isLoaderRow) {
                        return Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: isLoadingMore
                                ? CircularProgressIndicator()
                                : Text('Pull up to load more headlines'),
                          ),
                        );
                      }

                      return NewsArticleTile(article: filteredArticles[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class NewsArticleTile extends StatelessWidget {
  final Article article;

  const NewsArticleTile({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        leading: CachedNetworkImage(
          imageUrl: article.urlToImage,
          width: 100,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) =>
              Icon(Icons.error, color: Colors.red),
        ),
        title: Text(article.title),
        subtitle: Text(article.description),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailPage(article: article),
            ),
          );
        },
      ),
    );
  }
}
