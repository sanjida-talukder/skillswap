import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

class ApiService {
  // Physical Android phone: keep adb reverse tcp:8000 tcp:8000 active.
  static Future<Map<String, String>> _authHeaders({
    bool json = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('skillswap_access_token');

    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('skillswap_access_token');
  }
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const Duration _timeout = Duration(seconds: 20);
  static Future<IOWebSocketChannel> connectPostSocket(
    String postId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('skillswap_access_token');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again');
    }

    final wsBaseUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    return IOWebSocketChannel.connect(
      Uri.parse(
        '$wsBaseUrl/social/ws/posts/${Uri.encodeComponent(postId)}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }
  static Future<IOWebSocketChannel> connectFeedSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('skillswap_access_token');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again');
    }

    final wsBaseUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    return IOWebSocketChannel.connect(
      Uri.parse('$wsBaseUrl/social/ws/feed'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }

  static const List<String> reactions = [
    'like',
    'dislike',
  ];

  static const List<String> postPrivacyOptions = [
    'public',
    'followers',
    'private',
  ];

  // ---------- Response handling ----------

  static Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = <String, dynamic>{};
    }

    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      (data['detail'] ??
              data['message'] ??
              'Request failed (${response.statusCode})')
          .toString(),
    );
  }

  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return '$baseUrl$path';
  }

  // ---------- Authentication ----------

  static Future<Map<String, dynamic>> register({
    required String uniqueUsername,
    required String email,
    required String password,
    required String fullName,
    required String teachSkill,
    required String learnSkill,
  }) async {
    return _post('/register', {
      'unique_username': uniqueUsername,
      'email': email,
      'password': password,
      'full_name': fullName,
      'teach_skill': teachSkill,
      'learn_skill': learnSkill,
    });
  }

    // ---------- Email OTP Verification ----------

    static Future<Map<String, dynamic>> sendEmailOTP({
      required String email,
    }) async {
      return _post('/send-email-otp', {
        'email': email.trim(),
      });
    }

    static Future<Map<String, dynamic>> verifyEmailOTP({
      required String email,
      required String otp,
    }) async {
      return _post('/verify-email-otp', {
        'email': email.trim(),
        'otp': otp.trim(),
      });
    }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/login', {
      'email': email,
      'password': password,
    });

    final token = data['access_token']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('JWT token not received');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skillswap_access_token', token);

    return data;
  }

  static Future<Map<String, dynamic>> checkUsername(
    String username,
  ) async {
    final encoded = Uri.encodeComponent(username);
    return _get('/check-username/$encoded');
  }

  // ---------- Skills ----------

  static Future<List<dynamic>> findSkills({
    String search = '',
  }) async {
    final data = await _get(
      '/skills',
      {'search': search},
    );

    return (data['skills'] as List?) ?? [];
  }

  // ---------- Profiles ----------

  static Future<Map<String, dynamic>> getProfile(
    String userId,
  ) async {
    return _get(
      '/social/profile/$userId',
      {'viewer_id': userId},
    );
  }

  static Future<Map<String, dynamic>> getPublicProfile(
    String targetId,
    String viewerId,
  ) async {
    return _get(
      '/social/profile/$targetId',
      {'viewer_id': viewerId},
    );
  }

  static Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    return _put('/social/profile/$userId', data);
  }

  // ---------- Feed ----------

  static Future<Map<String, dynamic>> getFeed(
    String userId, {
    int offset = 0,
    int limit = 20,
  }) async {
    return _get('/social/feed', {
      'user_id': userId,
      'offset': '$offset',
      'limit': '$limit',
    });
  }

  // ---------- Create and edit posts ----------

  static Future<Map<String, dynamic>> createPost(
    String userId,
    String content, {
    String imageUrl = '',
    String youtubeUrl = '',
    String privacy = 'public',
  }) async {
    return _post('/social/posts', {
      'user_id': userId,
      'content': content,
      'image_url': imageUrl,
      'youtube_url': youtubeUrl,
      'privacy': privacy,
    });
  }

  static Future<Map<String, dynamic>> updatePost(
    String postId, {
    required String userId,
    required String content,
    String privacy = 'public',
  }) async {
    return _put('/social/posts/$postId', {
      'user_id': userId,
      'content': content,
      'privacy': privacy,
    });
  }

  static Future<Map<String, dynamic>> deletePost(
    String postId,
    String userId,
  ) async {
    return _delete(
      '/social/posts/$postId',
      {'user_id': userId},
    );
  }

  // ---------- Post reactions ----------

  static Future<Map<String, dynamic>> react(
    String postId,
    String userId,
    String reaction,
  ) async {
    if (!reactions.contains(reaction)) {
      throw ArgumentError('Unsupported reaction: $reaction');
    }

    return _post('/social/posts/$postId/react', {
      'user_id': userId,
      'reaction': reaction,
    });
  }

  // ---------- Comments and replies ----------

  static Future<Map<String, dynamic>> getComments(
    String postId, {
    String? currentUserId,
  }) async {
    final query = <String, String>{};

    if (currentUserId != null && currentUserId.isNotEmpty) {
      query['current_user_id'] = currentUserId;
    }

    return _get(
      '/social/posts/$postId/comments',
      query.isEmpty ? null : query,
    );
  }

  static Future<Map<String, dynamic>> addComment(
    String postId,
    String userId,
    String content, {
    String? parentCommentId,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'content': content,
    };

    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      body['parent_comment_id'] = parentCommentId;
    }

    return _post('/social/posts/$postId/comments', body);
  }

  static Future<Map<String, dynamic>> reactToComment(
    String commentId,
    String userId,
    String reaction,
  ) async {
    if (!reactions.contains(reaction)) {
      throw ArgumentError('Unsupported reaction: $reaction');
    }

    return _post('/social/comments/$commentId/react', {
      'user_id': userId,
      'reaction': reaction,
    });
  }

  static Future<Map<String, dynamic>> deleteComment(
    String commentId,
    String userId,
  ) async {
    return _delete(
      '/social/comments/$commentId',
      {'user_id': userId},
    );
  }

  // ---------- Media uploads ----------

  static Future<Map<String, dynamic>> uploadPicture(
    String userId,
    File file,
  ) async {
    return _upload('/social/upload/$userId', file);
  }

  // Existing image upload endpoint.
  static Future<Map<String, dynamic>> uploadPostImage(
    String userId,
    File file,
  ) async {
    return _upload('/social/upload-post-image/$userId', file);
  }

  // For multiple images/videos, the matching backend upload endpoint
  // and social_post_media attachment API must also be implemented.
  static Future<Map<String, dynamic>> uploadPostMedia(
    String userId,
    File file,
  ) async {
    return _upload('/social/upload-post-media/$userId', file);
  }

    static Future<Map<String, dynamic>> attachPostMedia({
      required String postId,
      required String userId,
      required String fileUrl,
      required String fileType,
    }) async {
      return _post('/social/posts/$postId/media', {
        'user_id': userId,
        'file_url': fileUrl,
        'file_type': fileType,
      });
    }

  // ---------- People and follow requests ----------

  static Future<Map<String, dynamic>> getPeople(
    String userId, {
    String search = '',
  }) async {
    return _get('/social/people', {
      'user_id': userId,
      'search': search,
    });
  }

  static Future<Map<String, dynamic>> follow(
    String senderId,
    String receiverId,
  ) async {
    return _post('/social/follow-requests', {
      'sender_id': senderId,
      'receiver_id': receiverId,
    });
  }

  static Future<Map<String, dynamic>> getFollowRequests(
    String userId,
  ) async {
    return _get('/social/follow-requests/$userId');
  }

  static Future<Map<String, dynamic>> respondFollowRequest(
    String requestId,
    String userId,
    bool accept,
  ) async {
    return _post('/social/follow-requests/$requestId/respond', {
      'user_id': userId,
      'accept': accept,
    });
  }

  // ---------- Messaging ----------

  static Future<Map<String, dynamic>> getConversations(
    String userId,
  ) async {
    return _get('/social/messages/$userId/conversations');
  }

  static Future<Map<String, dynamic>> getMessages(
    String userId,
    String otherId,
  ) async {
    return _get('/social/messages/$userId/with/$otherId');
  }

  static Future<Map<String, dynamic>> sendMessage(
    String senderId,
    String receiverId,
    String content,
  ) async {
    return _post('/social/messages', {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
    });
  }

  // ---------- Ratings ----------

  static Future<Map<String, dynamic>> getRatings(
    String userId,
  ) async {
    return _get('/ratings/$userId');
  }

  static Future<Map<String, dynamic>> submitRating({
    required String raterId,
    required String ratedUserId,
    required int rating,
    String review = '',
  }) async {
    return _post('/ratings', {
      'rater_id': raterId,
      'rated_user_id': ratedUserId,
      'rating': rating,
      'review': review,
    });
  }

  // ---------- Settings ----------

  static Future<Map<String, dynamic>> getSettings(
    String userId,
  ) async {
    return _get('/social/settings/$userId');
  }

  static Future<Map<String, dynamic>> updateSettings(
    String userId,
    Map<String, dynamic> data,
  ) async {
    return _put('/social/settings/$userId', data);
  }

  // ---------- HTTP helpers ----------

  static Future<Map<String, dynamic>> _upload(
    String path,
    File file,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$path'),
    );
    request.headers.addAll(await _authHeaders());

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final streamed = await request.send().timeout(
      const Duration(minutes: 5),
    );
    final response = await http.Response.fromStream(streamed);

    return _decode(response);
  }

  static Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    var uri = Uri.parse('$baseUrl$path');

    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: await _authHeaders(json: true),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _decode(response);
  }

  static Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: await _authHeaders(json: true),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _decode(response);
  }

  static Future<Map<String, dynamic>> _delete(
    String path, [
    Map<String, String>? query,
  ]) async {
    var uri = Uri.parse('$baseUrl$path');

    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final response = await http
        .delete(uri, headers: await _authHeaders())
        .timeout(_timeout);
    return _decode(response);
  }
}
