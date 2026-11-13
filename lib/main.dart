import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'dart:async';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

const Color brand = Color(0xFF0F766E);
const Color ink = Color(0xFF172554);

void main() => runApp(const SkillSwapApp());

class SkillSwapApp extends StatelessWidget {
  const SkillSwapApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SkillSwap', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: brand), scaffoldBackgroundColor: const Color(0xFFF5F7FA), appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F7FA), foregroundColor: ink)),
    home: const SessionGate(),
  );
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override State<SessionGate> createState() => _SessionGateState();
}
class _SessionGateState extends State<SessionGate> {
  late Future<Map<String,dynamic>?> session = _load();
  Future<Map<String,dynamic>?> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('skillswap_session');
    if (raw == null) return null;
    try { return Map<String,dynamic>.from(jsonDecode(raw) as Map); }
    catch (_) { await prefs.remove('skillswap_session'); return null; }
  }
  @override Widget build(BuildContext context) => FutureBuilder<Map<String,dynamic>?>(future:session,builder:(context,s) {
    if (s.connectionState != ConnectionState.done) return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if (s.data == null) return const AuthScreen();
    return SocialHome(user: s.data!);
  });
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(), password = TextEditingController(), name = TextEditingController(), username = TextEditingController(), teach = TextEditingController(text:'Other'), learn = TextEditingController(text:'Other');
  bool registering = false, busy = false, obscure = true;
  Timer? usernameTimer;
  String usernameStatus = '';
  bool checkingUsername = false;
  @override void dispose(){
  email.dispose();
  password.dispose();
  name.dispose();
  username.dispose();
  teach.dispose();
  learn.dispose();
  usernameTimer?.cancel();
  super.dispose(); }
  void onUsernameChanged(String value) {
    usernameTimer?.cancel();
    setState(() {
      usernameStatus = '';
      checkingUsername = false;
    });

    final value = username.text.trim();

    if (value.length < 3) return;

    setState(() => checkingUsername = true);

    usernameTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final result = await ApiService.checkUsername(value);

        if (!mounted || username.text.trim() != value) return;

        setState(() {
          checkingUsername = false;
          usernameStatus = result['available'] == true
              ? 'Username available'
              : 'Username already taken';
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          checkingUsername = false;
          usernameStatus = 'Could not check username';
        });
      }
    });
  }

Future<void> submit() async {
  if (email.text.trim().isEmpty ||
      password.text.isEmpty ||
      (registering &&
          (name.text.trim().isEmpty ||
              username.text.trim().isEmpty))) {
    _snack('Please complete the required fields.');
    return;
  }

  if (registering && password.text.length < 6) {
    _snack('Password must be at least 6 characters.');
    return;
  }

  setState(() => busy = true);

  try {
    if (registering) {
      final check =
          await ApiService.checkUsername(username.text.trim());

      if (check['available'] != true) {
        throw Exception('Username already exists. Choose another.');
      }

      await ApiService.register(
        uniqueUsername: username.text.trim(),
        email: email.text.trim(),
        password: password.text,
        fullName: name.text.trim(),
        teachSkill: teach.text.trim().isEmpty
            ? 'Other'
            : teach.text.trim(),
        learnSkill: learn.text.trim().isEmpty
            ? 'Other'
            : learn.text.trim(),
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: email.text.trim(),
          ),
        ),
      );

      return;
    }

    final data = await ApiService.login(
      email: email.text.trim(),
      password: password.text,
    );

    final user = Map<String, dynamic>.from(data['user'] as Map);

    final sessionData = {
      'userId': '${user['user_id'] ?? ''}',
      'name': '${user['full_name'] ?? name.text}',
      'username': '${user['unique_username'] ?? username.text}',
      'email': '${user['email'] ?? email.text}',
      'teachSkill': '${user['teach_skill'] ?? 'Not added yet'}',
      'learnSkill': '${user['learn_skill'] ?? 'Not added yet'}',
    };

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'skillswap_session',
      jsonEncode(sessionData),
    );

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => SocialHome(user: sessionData),
      ),
      (_) => false,
    );
  } catch (e) {
    _snack(e.toString().replaceFirst('Exception: ', ''));
  } finally {
    if (mounted) {
      setState(() => busy = false);
    }
  }
}

  void _snack(String s){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Icon(Icons.swap_horiz_rounded,size:68,color:brand),const SizedBox(height:8),const Text('SkillSwap',textAlign:TextAlign.center,style:TextStyle(fontSize:32,fontWeight:FontWeight.bold,color:ink)),const SizedBox(height:4),const Text('Learn. Teach. Connect.',textAlign:TextAlign.center,style:TextStyle(color:Colors.blueGrey)),const SizedBox(height:28),
    SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Login'),icon:Icon(Icons.login)),ButtonSegment(value:true,label:Text('Create account'),icon:Icon(Icons.person_add_alt_1))],selected:{registering},onSelectionChanged:(v)=>setState(()=>registering=v.first)),const SizedBox(height:20),
    if(registering)...[_field(name,'Full name',Icons.person),const SizedBox(height:12),Column(
                                                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                                                         children: [
                                                                                           TextField(
                                                                                             controller: username,
                                                                                             onChanged: onUsernameChanged,
                                                                                             decoration: InputDecoration(
                                                                                               labelText: 'Username',
                                                                                               prefixIcon: const Icon(Icons.alternate_email),
                                                                                               suffixIcon: checkingUsername
                                                                                                   ? const Padding(
                                                                                                       padding: EdgeInsets.all(12),
                                                                                                       child: SizedBox(
                                                                                                         width: 18,
                                                                                                         height: 18,
                                                                                                         child: CircularProgressIndicator(strokeWidth: 2),
                                                                                                       ),
                                                                                                     )
                                                                                                   : null,
                                                                                               border: OutlineInputBorder(
                                                                                                 borderRadius: BorderRadius.circular(14),
                                                                                               ),
                                                                                             ),
                                                                                           ),
                                                                                           if (usernameStatus.isNotEmpty)
                                                                                             Padding(
                                                                                               padding: const EdgeInsets.only(top: 6, left: 12),
                                                                                               child: Text(
                                                                                                 usernameStatus,
                                                                                                 style: TextStyle(
                                                                                                   color: usernameStatus == 'Username available'
                                                                                                       ? Colors.green
                                                                                                       : Colors.red,
                                                                                                 ),
                                                                                               ),
                                                                                             ),
                                                                                         ],
                                                                                       )],
    if(registering)const SizedBox(height:12),_field(email,'Email',Icons.email,keyboard:TextInputType.emailAddress),const SizedBox(height:12),TextField(controller:password,obscureText:obscure,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility:Icons.visibility_off)),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)))),
    if(registering)...[const SizedBox(height:12),_field(teach,'Skill I can teach',Icons.school),const SizedBox(height:12),_field(learn,'Skill I want to learn',Icons.auto_stories)],const SizedBox(height:22),FilledButton(onPressed:busy?null:submit,style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)),child:busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2)):Text(registering?'Create account':'Login')),const SizedBox(height:12),const Text('Connect with learners, share your skills, and grow together.',textAlign:TextAlign.center,style:TextStyle(color:Colors.blueGrey)),
  ]))))));
  Widget _field(TextEditingController c,String label,IconData icon,{TextInputType? keyboard})=>TextField(controller:c,keyboardType:keyboard,decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))));
}

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {
  final otpController = TextEditingController();

  bool sending = false;
  bool verifying = false;
  String message = 'Sending verification code...';

  @override
  void initState() {
    super.initState();
    sendOtp();
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> sendOtp() async {
    if (sending) return;

    setState(() {
      sending = true;
      message = 'Sending verification code...';
    });

    try {
      await ApiService.sendEmailOTP(email: widget.email);

      if (!mounted) return;

      setState(() {
        message = 'A 6-digit verification code has been sent to your email.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> verifyOtp() async {
    final code = otpController.text.trim();

    if (code.length != 6 || int.tryParse(code) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP.'),
        ),
      );
      return;
    }

    setState(() => verifying = true);

    try {
      await ApiService.verifyEmailOTP(
        email: widget.email,
        otp: code,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully. Please log in.'),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 75,
                    color: brand,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Verify your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a verification code to:\n${widget.email}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Enter 6-digit OTP',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: verifying ? null : verifyOtp,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: verifying
                        ? const CircularProgressIndicator()
                        : const Text('Verify Email'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: sending ? null : sendOtp,
                    child: Text(
                      sending ? 'Sending...' : 'Resend OTP',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SocialHome extends StatefulWidget {
  final Map<String,dynamic> user;
  const SocialHome({super.key,required this.user});
  @override State<SocialHome> createState()=>_SocialHomeState();
}

class _SocialHomeState extends State<SocialHome> {
  int index = 0;
  int refresh = 0;

  void reload() => setState(() => refresh++);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      FeedScreen(
        user: widget.user,
        key: ValueKey('feed$refresh'),
        onChanged: reload,
      ),
      RequestsScreen(
        user: widget.user,
        key: ValueKey('requests$refresh'),
      ),
      NotificationsScreen(
        user: widget.user,
        key: ValueKey('notifications$refresh'),
      ),
      MyProfileScreen(
        user: widget.user,
        key: ValueKey('profile$refresh'),
        onLogout: logout,
      ),
      MessagesScreen(
        user: widget.user,
        key: ValueKey('messages$refresh'),
      ),
      PeopleScreen(
        user: widget.user,
        key: ValueKey('people$refresh'),
      ),
      SettingsScreen(
        user: widget.user,
        key: ValueKey('settings$refresh'),
        onLogout: logout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SkillSwap',
          style: TextStyle(fontWeight: FontWeight.bold, color: brand),
        ),
        actions: [
          IconButton(
            tooltip: 'Messenger',
            onPressed: () => setState(() => index = 4),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          PopupMenuButton<String>(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onSelected: (value) {
              if (value == 'people') {
                setState(() => index = 5);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SkillSearchScreen(user: widget.user),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'people',
                child: Text('Search People'),
              ),
              PopupMenuItem(
                value: 'skills',
                child: Text('Search Skills'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => setState(() => index = 6),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 4 ? index : 0,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_alt_outlined),
            selectedIcon: Icon(Icons.person_add_alt),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('skillswap_session');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }
}

class FeedScreen extends StatefulWidget { final Map<String,dynamic> user; final VoidCallback onChanged; const FeedScreen({super.key,required this.user,required this.onChanged}); @override State<FeedScreen> createState()=>_FeedScreenState(); }
class _FeedScreenState extends State<FeedScreen>{
  final composer = TextEditingController();
  List<dynamic> posts = [];
  bool loading = true, sending = false;
  String? error;
  List<File> images = [];
  String postPrivacy = 'public';
  String get uid=>'${widget.user['userId']??''}';
  IOWebSocketChannel? _feedSocket;
  StreamSubscription? _feedSocketSubscription;
  @override
  void initState() {
    super.initState();
    load();
    _connectFeedSocket();
  }
  Future<void> _connectFeedSocket() async {
    try {
      final channel = await ApiService.connectFeedSocket();

      if (!mounted) {
        channel.sink.close();
        return;
      }

      _feedSocket = channel;

      _feedSocketSubscription = channel.stream.listen(
        (event) {
          if (!mounted) return;

          try {
            final data = jsonDecode(event.toString());
            final postId = '${data['post_id']}';
            final type = data['type'];

            final index = posts.indexWhere(
              (post) => '${post['post_id']}' == postId,
            );

            if (index == -1) return;

            setState(() {
              if (type == 'post_reaction') {
                posts[index]['like_count'] = data['like_count'];
                posts[index]['dislike_count'] = data['dislike_count'];
              } else if (type == 'new_comment') {
                final current =
                    int.tryParse('${posts[index]['comment_count'] ?? 0}') ?? 0;

                posts[index]['comment_count'] = current + 1;
              }
            });
          } catch (_) {}
        },
        onError: (e) {
          debugPrint('FEED SOCKET STREAM ERROR: $e');
          },

      );
    } catch (e) {
      debugPrint('FEED SOCKET ERROR: $e');
    }
  }

  @override
  void dispose() {
    _feedSocketSubscription?.cancel();
    _feedSocket?.sink.close();
    composer.dispose();
    super.dispose();
  }
  Future<void> load() async { setState(() => loading = true); try { final d = await ApiService.getFeed(uid); if (!mounted) return; setState(() { posts = (d['posts'] as List?) ?? []; loading = false; error = null; }); } catch (e) { if (!mounted) return; setState(() { loading = false; error = e.toString(); }); } }
    Future<void> pickImage() async {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose multiple photos'),
                onTap: () => Navigator.pop(context, 'photos'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Choose a video'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
            ],
          ),
        ),
      );

      if (choice == null) return;

      if (choice == 'photos') {
        final selected = await ImagePicker().pickMultiImage(
          imageQuality: 82,
        );

        if (selected.isNotEmpty && mounted) {
          setState(() {
            images.addAll(selected.map((x) => File(x.path)));
          });
        }
      } else {
        final selected = await ImagePicker().pickVideo(
          source: ImageSource.gallery,
        );

        if (selected != null && mounted) {
          setState(() {
            images.add(File(selected.path));
          });
        }
      }
    }
  Future<void> publish() async {
    if (composer.text.trim().isEmpty && images.isEmpty) return;

    setState(() => sending = true);

    try {
      String imageUrl = '';

      final result = await ApiService.createPost(
        uid,
        composer.text.trim(),
        imageUrl: imageUrl,
        privacy: postPrivacy,
      );

      final postId = '${result['post_id'] ?? ''}';

      if (postId.isEmpty) {
        throw Exception('Post create failed: post ID missing');
      }

      for (final file in images) {
        final uploaded = await ApiService.uploadPostMedia(uid, file);
        final fileUrl = '${uploaded['url'] ?? ''}';
        final fileType = '${uploaded['file_type'] ?? ''}';

        if (fileUrl.isEmpty || fileType.isEmpty) {
          throw Exception('A media file upload failed');
        }

        await ApiService.attachPostMedia(
          postId: postId,
          userId: uid,
          fileUrl: fileUrl,
          fileType: fileType,
        );
      }

      composer.clear();

      if (mounted) {
        setState(() {
          images.clear();
        });
      }

      await load();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
  Future<void> react(
    Map<String, dynamic> p,
    String reaction,
  ) async {
    try {
      await ApiService.react(
        '${p['post_id']}',
        uid,
        reaction,
      );
      await load();
    } catch (e) {
      _snack(e.toString());
    }
  }
  Future<void> comments(Map<String,dynamic> p)async{await showModalBottomSheet(context:context,isScrollControlled:true,builder:(_)=>CommentsSheet(post:p,user:widget.user));await load();}
  Future<void> editPost(Map<String, dynamic> post) async {
    final controller = TextEditingController(
      text: '${post['content'] ?? ''}',
    );

    final updatedContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit post'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          maxLength: 5000,
          decoration: const InputDecoration(
            hintText: 'Write your post...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );



    if (updatedContent == null) return;

    try {
      await ApiService.updatePost(
        '${post['post_id']}',
        userId: uid,
        content: updatedContent,
        privacy: '${post['privacy'] ?? 'public'}',
      );

      await load();

      if (mounted) _snack('Post updated successfully.');
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
  }
  Future<void> deletePost(Map<String, dynamic> post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deletePost('${post['post_id']}', uid);
      await load();
      if (mounted) _snack('Post deleted successfully.');
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
  }
  void _snack(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s.replaceFirst('Exception: ',''))));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('SkillSwap',style:TextStyle(fontWeight:FontWeight.bold,color:brand)),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(14,8,14,24),children:[
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[const CircleAvatar(child:Icon(Icons.person)),const SizedBox(width:10),Expanded(child:Text('What would you like to share, ${widget.user['name']??'learner'}?',style:const TextStyle(fontWeight:FontWeight.w600)))]),const SizedBox(height:12),TextField(controller:composer,minLines:2,maxLines:5,maxLength:5000,decoration:const InputDecoration(hintText:'Share a skill, question, progress or idea...',border:OutlineInputBorder())),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(
      initialValue: postPrivacy,
      decoration: const InputDecoration(
        labelText: 'Post audience',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'public', child: Text('Public')),
        DropdownMenuItem(value: 'followers', child: Text('Followers')),
        DropdownMenuItem(value: 'private', child: Text('Only me')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => postPrivacy = value);
      },
    ),
    if (images.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < images.length; i++)
              Chip(
                avatar: const Icon(Icons.perm_media_outlined),
                label: Text('Media ${i + 1}'),
                onDeleted: () => setState(() => images.removeAt(i)),
              ),
          ],
        ),
      ),
      Row(children:[TextButton.icon(onPressed:pickImage,icon:const Icon(Icons.image_outlined),label:const Text('Photo')),const Spacer(),FilledButton.icon(onPressed:sending?null:publish,icon:const Icon(Icons.send),label:Text(sending?'Posting...':'Post'))])]))),
    if(loading)const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator())),if(error!=null)Card(child:ListTile(leading:const Icon(Icons.error_outline,color:Colors.red),title:const Text('Could not load feed'),subtitle:Text(error!),trailing:IconButton(onPressed:load,icon:const Icon(Icons.refresh)))),if(!loading&&error==null&&posts.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(28),child:Column(children:[Icon(Icons.forum_outlined,size:42,color:brand),SizedBox(height:10),Text('Your feed is ready',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),SizedBox(height:5),Text('Create the first post or discover people to follow.',textAlign:TextAlign.center)]))),
    ...posts.map((raw){final p=Map<String,dynamic>.from(raw as Map);return PostCard(post:p,user:widget.user,onReact: (reaction) => react(p, reaction),onComments:()=>comments(p),
                                                                                                                                 onEdit: () => editPost(p),
                                                                                                                                 onDelete: () => deletePost(p),
                                                                                                                                 onProfile:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PublicProfileScreen(targetId:'${p['user_id']}',user:widget.user))));}),
  ])));
}

class PostCard extends StatelessWidget {
  final Map<String,dynamic> post;
  final Map<String,dynamic> user;
  final void Function(String) onReact;
  final VoidCallback onComments,onProfile;
  final VoidCallback? onEdit,onDelete;
  const PostCard({
    super.key,
    required this.post,
    required this.user,
    required this.onReact,
    required this.onComments,
    required this.onProfile,
    this.onEdit,
    this.onDelete,
  });
  @override Widget build(BuildContext context){final pic=ApiService.imageUrl(post['profile_picture_url']?.toString());final img=ApiService.imageUrl(post['image_url']?.toString());
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[GestureDetector(onTap:onProfile,child:CircleAvatar(backgroundImage:pic.isNotEmpty?NetworkImage(pic):null,child:pic.isEmpty?const Icon(Icons.person):null)),const SizedBox(width:10),Expanded(child:InkWell(onTap:onProfile,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${post['full_name']??post['unique_username']??'SkillSwap user'}',style:const TextStyle(fontWeight:FontWeight.bold)),Text('@${post['unique_username']??'user'} · ${_date(post['created_at'])}',style:Theme.of(context).textTheme.bodySmall)]))),
  PopupMenuButton<String>(
    icon: const Icon(Icons.more_horiz),
    onSelected: (value) {
      if (value == 'edit') {
        onEdit?.call();
      } else if (value == 'delete') {
        onDelete?.call();
      }
    },
    itemBuilder: (context) => [
      if ('${post['user_id']}' == '${user['userId'] ?? ''}') ...[
        const PopupMenuItem(
          value: 'edit',
          child: Text('Edit post'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete post'),
        ),
      ],
    ],
  )
  ]),
  if('${post['content']??''}'.trim().isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:13),child:Text('${post['content']}',style:const TextStyle(fontSize:15,height:1.4))),

if (post['media'] is List && (post['media'] as List).isNotEmpty)
  _PostMediaGrid(
    media: (post['media'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(),
  )
else if (img.isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      img,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Text('Image unavailable'),
    ),
  ),

    Row(
      children: [
        AnimatedScale(
          scale: post['my_reaction'] == 'like' ? 1.18 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.elasticOut,
          child: InkWell(
            onTap: () => onReact('like'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: post['my_reaction'] == 'like'
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '👍 ${post['like_count'] ?? 0}',
                style: TextStyle(
                  color: post['my_reaction'] == 'like'
                      ? Colors.blue
                      : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        AnimatedScale(
          scale: post['my_reaction'] == 'dislike' ? 1.18 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.elasticOut,
          child: InkWell(
            onTap: () => onReact('dislike'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: post['my_reaction'] == 'dislike'
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '👎 ${post['dislike_count'] ?? 0}',
                style: TextStyle(
                  color: post['my_reaction'] == 'dislike'
                      ? Colors.red
                      : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onComments,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${post['comment_count'] ?? 0} comments',
            ),
          ),
        ),
      ],
    ),
    ]))),
  );
  }
  static String _date(dynamic v){if(v==null)return 'now';try{final d=DateTime.parse(v.toString()).toLocal();return '${d.day}/${d.month}/${d.year}';}catch(_){return '';}}
}


class _PostMediaGrid extends StatelessWidget {
  final List<Map<String, dynamic>> media;

  const _PostMediaGrid({required this.media});

  @override
  Widget build(BuildContext context) {
    final visible = media.take(4).toList();

    Widget tile(Map<String, dynamic> item, {int extra = 0}) {
      final url = ApiService.imageUrl(item['file_url']?.toString());
      final type = '${item['file_type'] ?? ''}'.toLowerCase();
      final isVideo = type.startsWith('video/') ||
          type == 'application/octet-stream' &&
              RegExp(r'\.(mp4|mov|m4v|webm|3gp)$', caseSensitive: false)
                  .hasMatch(url);

      if (isVideo) {
        return PostVideoPlayer(url: url);
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
          if (extra > 0)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Text(
                '+$extra',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      );
    }

    if (media.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: tile(media.first),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 260,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: media.length == 2 ? 2 : 2,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final extra = index == 3 && media.length > 4
                ? media.length - 4
                : 0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: tile(visible[index], extra: extra),
            );
          },
        ),
      ),
    );
  }
}




class PostVideoPlayer extends StatefulWidget {
  final String url;
  final bool fullscreen;

  const PostVideoPlayer({
    super.key,
    required this.url,
    this.fullscreen = false,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final VideoPlayerController controller;
  String? errorMessage;
  bool controlsVisible = true;

  void toggleControls() {
    setState(() {
      controlsVisible = !controlsVisible;
    });
  }

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );

    controller.initialize().then((_) async {
      if (!mounted) return;
      await controller.setLooping(false);
      if (mounted) setState(() {});
    }).catchError((error) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Video could not be loaded';
      });
    });
  }

  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void togglePlay() async {
    debugPrint('NORMAL PLAY BUTTON PRESSED');

    if (!controller.value.isInitialized) {
      debugPrint('VIDEO NOT INITIALIZED');
      return;
    }

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
        debugPrint('VIDEO PAUSED');
      } else {
        await controller.play();
        debugPrint('VIDEO PLAYING');
      }
    } catch (e) {
      debugPrint('VIDEO PLAY ERROR: $e');
    }
  }

  Future<void> openFullscreen() async {
    if (!controller.value.isInitialized) return;

    await controller.pause();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenPostVideo(url: widget.url),
      ),
    );

    if (mounted && controller.value.isInitialized) {
      setState(() {});
    }
  }

  Widget buildVideo() {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;

        if (errorMessage != null || value.hasError) {
          return Container(
            height: 220,
            color: Colors.black,
            alignment: Alignment.center,
            child: const Text(
              'Unable to play this video',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (!value.isInitialized) {
          return Container(
            height: 220,
            color: Colors.black,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        }

        return AspectRatio(
          aspectRatio: value.aspectRatio > 0
              ? value.aspectRatio
              : 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Only the video surface handles play/pause taps.
              GestureDetector(
                onTap: toggleControls,
                child: Container(
                  color: Colors.black,
                  child: VideoPlayer(controller),
                ),
              ),

              if (value.isBuffering)
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),

              if (!value.isPlaying && !value.isBuffering)
                Center(
                  child: IconButton(
                    onPressed: togglePlay,
                    icon: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),

              // Separate controls: seek bar and buttons.
              if (controlsVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Row(
                        children: [
                          IconButton(
                            onPressed: togglePlay,
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.blue,
                                bufferedColor: Colors.white54,
                                backgroundColor: Colors.white24,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                          Text(
                            '${formatDuration(value.position)} / '
                            '${formatDuration(value.duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),

                          IconButton(
                            onPressed: openFullscreen,
                            icon: const Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullscreen) {
      return Center(child: buildVideo());
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: buildVideo(),
      ),
    );
  }
}

class FullscreenPostVideo extends StatefulWidget {
  final String url;

  const FullscreenPostVideo({
    super.key,
    required this.url,
  });

  @override
  State<FullscreenPostVideo> createState() =>
      _FullscreenPostVideoState();
}

class _FullscreenPostVideoState extends State<FullscreenPostVideo> {
  late final VideoPlayerController controller;
  String? errorMessage;
  bool controlsVisible = true;

  void toggleControls() {
    setState(() {
      controlsVisible = !controlsVisible;
    });
  }

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );

    controller.initialize().then((_) {
      if (!mounted) return;
      controller.play();
      setState(() {});
    }).catchError((error) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Video could not be loaded';
      });
    });
  }

  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void togglePlay() async {
    debugPrint('FULLSCREEN PLAY BUTTON PRESSED');

    if (!controller.value.isInitialized) {
      debugPrint('VIDEO NOT INITIALIZED');
      return;
    }

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
        debugPrint('VIDEO PAUSED');
      } else {
        await controller.play();
        debugPrint('VIDEO PLAYING');
      }
    } catch (e) {
      debugPrint('VIDEO PLAY ERROR: $e');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video'),
      ),
      body: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final value = controller.value;

            if (errorMessage != null || value.hasError) {
              return const Text(
                'Unable to play this video',
                style: TextStyle(color: Colors.white),
              );
            }

            if (!value.isInitialized) {
              return const CircularProgressIndicator(
                color: Colors.white,
              );
            }

            return AspectRatio(
              aspectRatio: value.aspectRatio > 0
                  ? value.aspectRatio
                  : 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: toggleControls,
                    child: VideoPlayer(controller),
                  ),
                  if (value.isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  if (!value.isPlaying && !value.isBuffering)
                    Center(
                      child: IconButton(
                        onPressed: () {
                          debugPrint('PLAY ICON TAPPED');
                          togglePlay();
                        },
                        icon: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
                  if (controlsVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      color: Colors.black54,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.blue,
                              bufferedColor: Colors.white54,
                              backgroundColor: Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: togglePlay,
                                icon: Icon(
                                  value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${formatDuration(value.position)} / '
                                '${formatDuration(value.duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(
                                  Icons.fullscreen_exit,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post, user;

  const CommentsSheet({
    super.key,
    required this.post,
    required this.user,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final input = TextEditingController();

    List<dynamic> comments = [];
    bool loading = true;
    bool sending = false;

    dynamic _postSocket;
    dynamic _postSocketSubscription;

  String? replyToId;
  String? replyToName;

  String get uid => '${widget.user['userId'] ?? ''}';

    @override
    void initState() {
      super.initState();
      load();
      _connectPostSocket();
    }
  Future<void> _connectPostSocket() async {
    try {
      final channel = await ApiService.connectPostSocket(
        '${widget.post['post_id']}',
      );

      if (!mounted) {
        await channel.sink.close();
        return;
      }

      _postSocket = channel;

      _postSocketSubscription = channel.stream.listen(
        (event) {
          if (!mounted) return;

          try {
            final data = jsonDecode(event.toString());

            if (data is Map &&
                (data['type'] == 'new_comment' ||
                 data['type'] == 'comment_reaction')) {
              load();
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }
    @override
    void dispose() {
      _postSocketSubscription?.cancel();
      _postSocket?.sink.close();
      input.dispose();
      super.dispose();
    }

  Future<void> load() async {
    try {
      final d = await ApiService.getComments(
        '${widget.post['post_id']}',
        currentUserId: uid,
      );

      if (mounted) {
        setState(() {
          comments = (d['comments'] as List?) ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> send() async {
    if (input.text.trim().isEmpty || sending) return;

    setState(() => sending = true);

    try {
      await ApiService.addComment(
        '${widget.post['post_id']}',
        uid,
        input.text.trim(),
        parentCommentId: replyToId,
      );

      input.clear();

      setState(() {
        replyToId = null;
        replyToName = null;
      });

      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  Future<void> reactComment(
    Map<String, dynamic> comment,
    String reaction,
  ) async {
    try {
      await ApiService.reactToComment(
        '${comment['comment_id']}',
        uid,
        reaction,
      );

      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> deleteComment(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text(
          'Are you sure you want to delete this comment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteComment(
        '${comment['comment_id']}',
        uid,
      );

      if (replyToId == comment['comment_id']) {
        setState(() {
          replyToId = null;
          replyToName = null;
        });
      }

      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> childrenOf(String commentId) {
    return comments
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) => '${item['parent_comment_id'] ?? ''}' == commentId,
        )
        .toList();
  }

  Widget buildComment(
    Map<String, dynamic> comment, {
    int depth = 0,
  }) {
    final commentId = '${comment['comment_id'] ?? ''}';
    final authorId = '${comment['user_id'] ?? ''}';
    final name =
        '${comment['full_name'] ?? comment['unique_username'] ?? 'Learner'}';
    final myReaction = '${comment['my_reaction'] ?? ''}';


    return Padding(
      key: ValueKey(commentId),
      padding: EdgeInsets.only(
        left: depth > 0 ? 22 : 0,
        top: 5,
        bottom: 5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundImage:
                    '${comment['profile_picture_url'] ?? ''}'.isNotEmpty
                        ? NetworkImage(
                            ApiService.imageUrl(
                              '${comment['profile_picture_url']}',
                            ),
                          )
                        : null,
                child:
                    '${comment['profile_picture_url'] ?? ''}'.isEmpty
                        ? const Icon(Icons.person, size: 18)
                        : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${comment['content'] ?? ''}'),
                    ],
                  ),
                ),
              ),
              if (authorId == uid)
                PopupMenuButton<String>(
                  tooltip: 'Comment options',
                  onSelected: (value) {
                    if (value == 'delete') {
                      deleteComment(comment);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete comment'),
                    ),
                  ],
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 45, top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                                TextButton.icon(
                                  onPressed: () => reactComment(comment, 'like'),
                                  icon: Icon(
                                    Icons.thumb_up,
                                    size: 16,
                                    color: myReaction == 'like' ? Colors.blue : null,
                                  ),
                                  label: Text(
                                    '${comment['like_count'] ?? 0}',
                                    style: TextStyle(
                                      color: myReaction == 'like' ? Colors.blue : null,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => reactComment(comment, 'dislike'),
                                  icon: Icon(
                                    Icons.thumb_down,
                                    size: 16,
                                    color: myReaction == 'dislike' ? Colors.red : null,
                                  ),
                                  label: Text(
                                    '${comment['dislike_count'] ?? 0}',
                                    style: TextStyle(
                                      color: myReaction == 'dislike' ? Colors.red : null,
                                    ),
                                  ),
                                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      replyToId = commentId;
                      replyToName = name;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reply'),
                ),
              ],
            ),
          ),
          ...childrenOf(commentId).map(
            (child) => buildComment(
              child,
              depth: depth + 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roots = comments
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) =>
              item['parent_comment_id'] == null ||
              '${item['parent_comment_id']}'.isEmpty,
        )
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : roots.isEmpty
                        ? const Center(
                            child: Text(
                              'No comments yet. Start the conversation.',
                            ),
                          )
                        : ListView(
                            children: roots
                                .map((comment) => buildComment(comment))
                                .toList(),
                          ),
              ),
              if (replyToId != null)
                Row(
                  children: [
                    Expanded(
                      child: Text('Replying to $replyToName'),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: () {
                        setState(() {
                          replyToId = null;
                          replyToName = null;
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class PeopleScreen extends StatefulWidget {final Map<String,dynamic> user;const PeopleScreen({super.key,required this.user});@override State<PeopleScreen> createState()=>_PeopleScreenState();}
class _PeopleScreenState extends State<PeopleScreen>{final search=TextEditingController();List<dynamic> people=[];bool loading=true;String get uid=>'${widget.user['userId']}';@override void initState(){super.initState();load();}@override void dispose(){search.dispose();super.dispose();}Future<void> load()async{setState(()=>loading=true);try{final d=await ApiService.getPeople(uid,search:search.text.trim());if(mounted)setState(()=>people=(d['people'] as List?)??[]);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>loading=false);}}Future<void> follow(String id)async{try{final d=await ApiService.follow(uid,id);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${d['message']??'Done'}')));await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Discover people')),body:Column(children:[Padding(padding:const EdgeInsets.all(14),child:TextField(controller:search,onSubmitted:(_)=>load(),decoration:InputDecoration(hintText:'Search name or username',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:load,icon:const Icon(Icons.arrow_forward)),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))))),Expanded(child:loading?const Center(child:CircularProgressIndicator()):people.isEmpty?const Center(child:Text('No people found.')):ListView.builder(itemCount:people.length,itemBuilder:(context,i){final p=Map<String,dynamic>.from(people[i] as Map);final id='${p['user_id']}';final followed=(p['is_following'] as num? ?? 0)>0;final status=p['request_status'];final pic=ApiService.imageUrl(p['profile_picture_url']?.toString());return Card(margin:const EdgeInsets.symmetric(horizontal:14,vertical:5),child:ListTile(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PublicProfileScreen(targetId:id,user:widget.user))),leading:CircleAvatar(backgroundImage:pic.isNotEmpty?NetworkImage(pic):null,child:pic.isEmpty?const Icon(Icons.person):null),title:Text('${p['full_name']??p['unique_username']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('@${p['unique_username']??''}'),trailing:Wrap(spacing:4,children:[IconButton(tooltip:'Message',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(user:widget.user,otherId:id,otherName:'${p['full_name']??p['unique_username']}'))),icon:const Icon(Icons.chat_bubble_outline)),if(followed)const Chip(label:Text('Following'))else if(status=='pending')const Chip(label:Text('Requested'))else IconButton(tooltip:'Follow',onPressed:()=>follow(id),icon:const Icon(Icons.person_add_alt_1,color:brand))])));} ))]));}

class RequestsScreen extends StatefulWidget {final Map<String,dynamic> user;const RequestsScreen({super.key,required this.user});@override State<RequestsScreen> createState()=>_RequestsScreenState();}
class _RequestsScreenState extends State<RequestsScreen>{List<dynamic> requests=[];bool loading=true;String get uid=>'${widget.user['userId']}';@override void initState(){super.initState();load();}Future<void> load()async{setState(()=>loading=true);try{final d=await ApiService.getFollowRequests(uid);if(mounted)setState(()=>requests=(d['requests'] as List?)??[]);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>loading=false);}}Future<void> respond(Map<String,dynamic> r,bool accept)async{try{await ApiService.respondFollowRequest('${r['request_id']}',uid,accept);await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Follow requests')),body:loading?const Center(child:CircularProgressIndicator()):requests.isEmpty?const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.person_add_disabled,size:46,color:brand),SizedBox(height:10),Text('No pending follow requests')])):ListView.builder(itemCount:requests.length,itemBuilder:(context,i){final r=Map<String,dynamic>.from(requests[i] as Map);return Card(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   child: ListTile(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     onTap: () {
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       Navigator.push(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         context,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         MaterialPageRoute(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           builder: (_) => PublicProfileScreen(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             targetId: '${r['sender_id']}',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             user: widget.user,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           ),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         ),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       );
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     },
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     leading: const CircleAvatar(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       child: Icon(Icons.person),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     ),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     title: Text(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       '${r['full_name'] ?? r['unique_username']}',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     ),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     subtitle: Text(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       '@${r['unique_username'] ?? ''} wants to follow you',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     ),trailing:Wrap(children:[IconButton(onPressed:()=>respond(r,false),icon:const Icon(Icons.close,color:Colors.red)),IconButton(onPressed:()=>respond(r,true),icon:const Icon(Icons.check_circle,color:brand))])));}));}

class MessagesScreen extends StatefulWidget {final Map<String,dynamic> user;const MessagesScreen({super.key,required this.user});@override State<MessagesScreen> createState()=>_MessagesScreenState();}
class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> conversations = [];
  bool loading = true;
  String get uid => '${widget.user['userId']}';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final d = await ApiService.getConversations(uid);
      if (mounted) setState(() => conversations = (d['conversations'] as List?) ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PeopleScreen(user: widget.user))),
          icon: const Icon(Icons.add_comment_outlined),
        )],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : conversations.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.chat_bubble_outline, size: 48, color: brand),
                    const SizedBox(height: 10),
                    const Text('No conversations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Discover people and tap the message icon to start a conversation.', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PeopleScreen(user: widget.user))),
                      child: const Text('Find people'),
                    ),
                  ]),
                ))
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, i) {
                    final c = Map<String, dynamic>.from(conversations[i] as Map);
                    final pic = ApiService.imageUrl(c['profile_picture_url']?.toString());
                    return ListTile(
                      leading: CircleAvatar(backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null, child: pic.isEmpty ? const Icon(Icons.person) : null),
                      title: Text('${c['full_name'] ?? c['unique_username']}'),
                      subtitle: Text('${c['last_message'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                          user: widget.user,
                          otherId: '${c['user_id']}',
                          otherName: '${c['full_name'] ?? c['unique_username']}',
                        ))).then((_) => load());
                      },
                    );
                  },
                ),
    );
  }
}

class ChatScreen extends StatefulWidget {final Map<String,dynamic> user;final String otherId,otherName;const ChatScreen({super.key,required this.user,required this.otherId,required this.otherName});@override State<ChatScreen> createState()=>_ChatScreenState();}
class _ChatScreenState extends State<ChatScreen>{final input=TextEditingController();List<dynamic> messages=[];bool loading=true,sending=false;String get uid=>'${widget.user['userId']}';@override void initState(){super.initState();load();}@override void dispose(){input.dispose();super.dispose();}Future<void> load()async{try{final d=await ApiService.getMessages(uid,widget.otherId);if(mounted)setState(()=>messages=(d['messages'] as List?)??[]);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>loading=false);}}Future<void> send()async{if(input.text.trim().isEmpty)return;final text=input.text.trim();setState(()=>sending=true);try{await ApiService.sendMessage(uid,widget.otherId,text);input.clear();await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>sending=false);}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.otherName)),body:Column(children:[Expanded(child:loading?const Center(child:CircularProgressIndicator()):messages.isEmpty?const Center(child:Text('Say hello to start chatting.')):ListView.builder(padding:const EdgeInsets.all(12),itemCount:messages.length,itemBuilder:(context,i){final m=Map<String,dynamic>.from(messages[i] as Map);final mine='${m['sender_id']}'==uid;return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Container(margin:const EdgeInsets.symmetric(vertical:4),padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),constraints:BoxConstraints(maxWidth:MediaQuery.of(context).size.width*.75),decoration:BoxDecoration(color:mine?brand:Colors.white,borderRadius:BorderRadius.circular(16)),child:Text('${m['content']}',style:TextStyle(color:mine?Colors.white:ink))));})),SafeArea(child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[Expanded(child:TextField(controller:input,minLines:1,maxLines:4,decoration:const InputDecoration(hintText:'Message...',border:OutlineInputBorder()))),const SizedBox(width:8),IconButton.filled(onPressed:sending?null:send,icon:const Icon(Icons.send))])))]));}

class MyProfileScreen extends StatefulWidget {final Map<String,dynamic> user;final Future<void> Function() onLogout;const MyProfileScreen({super.key,required this.user,required this.onLogout});@override State<MyProfileScreen> createState()=>_MyProfileScreenState();}
class _MyProfileScreenState extends State<MyProfileScreen> {
  Map<String, dynamic> profile = {};
  bool loading = true, saving = false;
  String get uid => '${widget.user['userId']}';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final d = await ApiService.getProfile(uid);
      if (mounted) setState(() => profile = Map<String, dynamic>.from(d['profile'] as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickPicture() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (x == null) return;
    setState(() => saving = true);
    try {
      final d = await ApiService.uploadPicture(uid, File(x.path));
      if (mounted) {
        setState(() => profile['profile_picture_url'] = d['url']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> edit() async {
    final fields = <String, TextEditingController>{
  for (final key in [
    'full_name',
    'bio',
    'hometown',
    'present_address',
    'school',
    'college',
    'date_of_birth',
    'teach_skill',
    'learn_skill',
  ])
    key: TextEditingController(
      text: '${profile[key] ?? (key == 'teach_skill' ? widget.user['teachSkill'] : key == 'learn_skill' ? widget.user['learnSkill'] : '') ?? ''}',
    ),
};
    String privacy = '${profile['privacy'] ?? 'public'}';
    double? selectedLatitude =
        double.tryParse('${profile['latitude'] ?? ''}');
    double? selectedLongitude =
        double.tryParse('${profile['longitude'] ?? ''}');
    String selectedLocationName =
        '${profile['selected_location'] ?? ''}';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Edit profile'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _editField(fields['full_name']!, 'Full name'),
                _editField(fields['bio']!, 'Bio', max: 3),
                _editField(fields['hometown']!, 'Hometown'),
                _editField(fields['present_address']!, 'Present address'),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('Choose location on map'),
                                  onPressed: () async {
                                    final picked = await showDialog<MapPickedLocation>(
                                      context: ctx,
                                      builder: (_) => MapLocationPicker(
                                        initialLocation:
                                            selectedLatitude != null &&
                                                    selectedLongitude != null
                                                ? LatLng(
                                                    selectedLatitude!,
                                                    selectedLongitude!,
                                                  )
                                                : LatLng(23.8103, 90.4125),
                                      ),
                                    );

                                    if (picked != null) {
                                      setDialog(() {
                                        selectedLatitude = picked.coordinates.latitude;
                                        selectedLongitude = picked.coordinates.longitude;
                                        selectedLocationName = picked.name;
                                      });
                                    }
                                  },
                                ),
                                if (selectedLatitude != null &&
                                    selectedLongitude != null)
                                  Text(
                                    'Location selected: ${selectedLatitude!.toStringAsFixed(5)}, ${selectedLongitude!.toStringAsFixed(5)}',
                                  ),
                                if (selectedLocationName.isNotEmpty)
                                  Text('Selected place: $selectedLocationName'),
                _editField(fields['school']!, 'School'),
                _editField(fields['college']!, 'College'),
                TextFormField(
                  controller: fields['date_of_birth'],
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    suffixIcon: Icon(Icons.calendar_month),
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final current = DateTime.tryParse(
                      fields['date_of_birth']!.text,
                    );

                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: current != null && !current.isAfter(now)
                          ? current
                          : DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: now,
                    );

                    if (picked != null) {
                      fields['date_of_birth']!.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                _editField(fields['teach_skill']!, 'Skills I can teach', max: 2),
                _editField(fields['learn_skill']!, 'Skills I want to learn', max: 2),
                DropdownButtonFormField<String>(
                  initialValue: privacy,
                  decoration: const InputDecoration(labelText: 'Account privacy'),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                  ],
                  onChanged: (v) => setDialog(() => privacy = v ?? 'public'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                for (final e in fields.entries) e.key: e.value.text,
                'privacy': privacy,
                'profile_picture_url': '${profile['profile_picture_url'] ?? ''}',
                'latitude': selectedLatitude,
                'longitude': selectedLongitude,
                'selected_location': selectedLocationName,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null) { for (final c in fields.values) { c.dispose(); } return; }
    setState(() => saving = true);
    try {
      await ApiService.updateProfile(uid, result);
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      for (final c in fields.values) { c.dispose(); }
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _editField(TextEditingController c, String label, {int max = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: c, minLines: max, maxLines: max, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );

  @override
  Widget build(BuildContext context) {
    final pic = ApiService.imageUrl(profile['profile_picture_url']?.toString());
    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(onPressed: edit, icon: const Icon(Icons.edit_outlined)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'settings') Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user, onLogout: widget.onLogout)));
              if (v == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'settings', child: Text('Settings')), PopupMenuItem(value: 'logout', child: Text('Log out'))],
          ),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            Stack(children: [
              CircleAvatar(radius: 52, backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null, child: pic.isEmpty ? const Icon(Icons.person, size: 52) : null),
              Positioned(right: 0, bottom: 0, child: CircleAvatar(backgroundColor: brand, child: IconButton(onPressed: saving ? null : pickPicture, color: Colors.white, icon: const Icon(Icons.camera_alt, size: 20)))),
            ]),
            const SizedBox(height: 12),
            Text('${profile['full_name'] ?? widget.user['name']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ink)),
            Text('@${profile['unique_username'] ?? widget.user['username'] ?? ''}', style: const TextStyle(color: Colors.blueGrey)),
            if ('${profile['bio'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${profile['bio']}', textAlign: TextAlign.center)),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 20, children: [_count('${profile['followers_count'] ?? 0}', 'Followers'), _count('${profile['following_count'] ?? 0}', 'Following')]),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: edit, icon: const Icon(Icons.edit), label: const Text('Edit profile')),
          ]))),
          _section('About you', Icons.info_outline, [
            _info(Icons.location_city, 'Hometown', profile['hometown']),
            _info(Icons.home_outlined, 'Present address', profile['present_address']),
            _info(Icons.place_outlined, 'Selected map location', profile['selected_location']),
            _info(Icons.school_outlined, 'School', profile['school']),
            _info(Icons.account_balance_outlined, 'College', profile['college']),
            _info(Icons.cake_outlined, 'Date of birth', profile['date_of_birth']),
            _info(Icons.lock_outline, 'Privacy', profile['privacy'] ?? 'public'),
          ]),
          _section('SkillSwap', Icons.auto_awesome, [
  _info(
    Icons.school,
    'Skills I can teach',
    profile['teach_skill'] ?? widget.user['teachSkill'],
  ),
  _info(
    Icons.menu_book,
    'Skills I want to learn',
    profile['learn_skill'] ?? widget.user['learnSkill'],
  ),
]),
RatingSection(
  targetUserId: uid,
  currentUserId: uid,
),

          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout), label: const Text('Log out')),
        ]),
      ),
    );
  }

  Widget _count(String n, String label) => Column(children: [Text(n, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.blueGrey))]);
  Widget _info(IconData icon, String label, dynamic value) => ListTile(dense: true, leading: Icon(icon, color: brand), title: Text(label), subtitle: Text(value == null || '$value'.isEmpty ? 'Not added' : '$value'));
  Widget _section(String title, IconData icon, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ListTile(leading: Icon(icon, color: brand), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), dense: true), ...children])));
}

class PublicProfileScreen extends StatefulWidget {
final String targetId;
final Map<String,dynamic> user;
const PublicProfileScreen({super.key,required this.targetId,required this.user});
@override State<PublicProfileScreen> createState()=>_PublicProfileScreenState();
}


class RatingSection extends StatefulWidget {
  final String targetUserId;
  final String currentUserId;

  const RatingSection({
    super.key,
    required this.targetUserId,
    required this.currentUserId,
  });

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection> {
  Map<String, dynamic> data = {};
  final reviewController = TextEditingController();
  int selectedRating = 0;
  bool loading = true;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    loadRatings();
  }

  Future<void> loadRatings() async {
    try {
      final result = await ApiService.getRatings(widget.targetUserId);
      if (mounted) setState(() => data = result);
    } catch (_) {
      // Keep the section available if ratings cannot load.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (selectedRating == 0) return;

    setState(() => submitting = true);
    try {
      await ApiService.submitRating(
        raterId: widget.currentUserId,
        ratedUserId: widget.targetUserId,
        rating: selectedRating,
        review: reviewController.text.trim(),
      );

      reviewController.clear();
      setState(() => selectedRating = 0);
      await loadRatings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviews = data['reviews'] as List? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ratings & Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (loading)
              const CircularProgressIndicator()
            else ...[
              Text(
                '${data['average_rating'] ?? 0} / 5  ⭐  (${data['count'] ?? 0} reviews)',
              ),
              if (widget.targetUserId != widget.currentUserId) ...[
                const SizedBox(height: 12),
                const Text('Rate this user'),
                Row(
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      onPressed: () => setState(() => selectedRating = i + 1),
                      icon: Icon(
                        i < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: reviewController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Write a review',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: submitting || selectedRating == 0 ? null : submit,
                  child: Text(submitting ? 'Submitting...' : 'Submit review'),
                ),
              ],
              const Divider(),
              ...reviews.map((r) => ListTile(
                leading: const Icon(Icons.person),
                title: Text('${r['reviewer_username'] ?? 'User'}'),
                subtitle: Text('${r['review'] ?? ''}'),
                trailing: Text('⭐ ${r['rating']}'),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _PublicProfileScreenState extends State<PublicProfileScreen>{Map<String,dynamic>? p;bool loading=true;String get uid=>'${widget.user['userId']}';@override void initState(){super.initState();load();}Future<void> load()async{try{final d=await ApiService.getPublicProfile(widget.targetId,uid);if(mounted)setState(()=>p=Map<String,dynamic>.from(d['profile'] as Map));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>loading=false);}}Future<void> follow()async{try{final d=await ApiService.follow(uid,widget.targetId);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${d['message']}')));await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}@override Widget build(BuildContext context){final profile=p??{};final pic=ApiService.imageUrl(profile['profile_picture_url']?.toString());return Scaffold(appBar:AppBar(title:const Text('Profile')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(children:[CircleAvatar(radius:48,backgroundImage:pic.isNotEmpty?NetworkImage(pic):null,child:pic.isEmpty?const Icon(Icons.person,size:48):null),const SizedBox(height:12),Text('${profile['full_name']??profile['unique_username']}',style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),Text('@${profile['unique_username']??''}',style:const TextStyle(color:Colors.blueGrey)),const SizedBox(height:10),Text('${profile['bio']??''}',textAlign:TextAlign.center),const SizedBox(height:10),Text('${profile['followers_count']??0} followers · ${profile['following_count']??0} following'),if(widget.targetId!=uid)Wrap(spacing:10,children:[FilledButton.icon(onPressed:follow,icon:const Icon(Icons.person_add_alt_1),label:const Text('Follow')),OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(user:widget.user,otherId:widget.targetId,otherName:'${profile['full_name']??profile['unique_username']}'))),icon:const Icon(Icons.chat_bubble_outline),label:const Text('Message'))])]))),Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          leading: Icon(Icons.auto_awesome),
          title: Text(
            'SkillSwap',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _detail('Skills I can teach', profile['teach_skill']),
        _detail('Skills I want to learn', profile['learn_skill']),
      ],
    ),
  ),
),
if (profile['can_view_details'] == true)
  Card(
    child: Column(
      children: [
        _detail('Hometown', profile['hometown']),
        _detail('School', profile['school']),
        _detail('College', profile['college']),
        _detail('Present address', profile['present_address']),
        _detail('Date of birth', profile['date_of_birth']),
      ],
    ),
  )
else
  const Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Text(
        'This is a private account. Follow request acceptance is required to view personal details.',
      ),
    ),
  ),
  RatingSection(
    targetUserId: widget.targetId,
    currentUserId: uid,
  ),
]));}Widget _detail(String l,dynamic v)=>ListTile(title:Text(l),subtitle:Text(v==null||'$v'.isEmpty?'Not shared':'$v'));}


class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  const SettingsScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool online = true;
  bool messagesEnabled = true;
  bool requestsEnabled = true;
  bool loading = true;
  bool saving = false;

  String allow = 'everyone';

  String get uid => '${widget.user['userId']}';

  bool readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await ApiService.getSettings(uid);
      final s = Map<String, dynamic>.from(d['settings'] as Map);

      if (!mounted) return;

      setState(() {
        notifications = readBool(s['notifications_enabled']);
        online = readBool(s['show_online']);
        messagesEnabled = readBool(s['messages_enabled']);
        requestsEnabled = readBool(s['requests_enabled']);
        allow = '${s['allow_messages'] ?? 'everyone'}';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() => saving = true);

    try {
      await ApiService.updateSettings(uid, {
        'notifications_enabled': notifications,
        'show_online': online,
        'allow_messages': allow,
        'messages_enabled': messagesEnabled,
        'requests_enabled': requestsEnabled,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & privacy')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.security, color: brand),
                        title: Text(
                          'Privacy and account',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Control how people interact with you.',
                        ),
                      ),
                      SwitchListTile(
                        value: notifications,
                        onChanged: (v) =>
                            setState(() => notifications = v),
                        title: const Text('Notifications'),
                        subtitle: const Text(
                          'Master switch for in-app notifications',
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: requestsEnabled,
                        onChanged: (v) =>
                            setState(() => requestsEnabled = v),
                        title: const Text('Follow request notifications'),
                        subtitle: const Text(
                          'Get notified when someone sends you a follow request',
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: messagesEnabled,
                        onChanged: (v) =>
                            setState(() => messagesEnabled = v),
                        title: const Text('Message notifications'),
                        subtitle: const Text(
                          'Get notified when someone messages you',
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: online,
                        onChanged: (v) => setState(() => online = v),
                        title: const Text('Show online status'),
                        subtitle: const Text(
                          'Display your active status setting',
                        ),
                      ),
                      ListTile(
                        title: const Text('Who can message me?'),
                        subtitle: const Text(
                          'Choose who is allowed to start a conversation',
                        ),
                        trailing: DropdownButton<String>(
                          value: allow,
                          items: const [
                            DropdownMenuItem(
                              value: 'everyone',
                              child: Text('Everyone'),
                            ),
                            DropdownMenuItem(
                              value: 'followers',
                              child: Text('Followers'),
                            ),
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('No one'),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => allow = v ?? 'everyone');
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: FilledButton(
                          onPressed: saving ? null : save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(
                            saving ? 'Saving...' : 'Save settings',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(
                          Icons.manage_accounts,
                          color: brand,
                        ),
                        title: Text('Account'),
                        subtitle: Text(
                          'Profile details, profile picture and Public/Private '
                          'setting are available under Profile → Edit profile.',
                        ),
                      ),
                      const ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('Account security'),
                        subtitle: Text(
                          'Use a strong unique password. Secure token-based '
                          'sign-in is a future hardening task.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ],
            ),
    );
  }
}


class SkillSearchScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SkillSearchScreen({
    super.key,
    required this.user,
  });

  @override
  State<SkillSearchScreen> createState() =>
      _SkillSearchScreenState();
}

class _SkillSearchScreenState
    extends State<SkillSearchScreen> {
  final TextEditingController searchController =
      TextEditingController();

  List<dynamic> skills = [];
  bool loading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadSkills();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadSkills() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.findSkills(
        search: searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        skills = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e
            .toString()
            .replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Skills'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onSubmitted: (_) => loadSkills(),
              decoration: InputDecoration(
                hintText: 'Search skills...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: loadSkills,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Could not load skills:\n$errorMessage',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : skills.isEmpty
                        ? const Center(
                            child: Text(
                              'No skills found. Try another keyword.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: skills.length,
                            itemBuilder: (context, index) {
                              final skill =
                                  Map<String, dynamic>.from(
                                skills[index] as Map,
                              );

                              final name =
                                  '${skill['name'] ?? 'Unnamed skill'}';
                              final category =
                                  '${skill['category_name'] ?? 'General'}';
                              final description =
                                  '${skill['description'] ?? ''}';

                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.school),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Category: $category'
                                    '${description.isNotEmpty ? '\n$description' : ''}',
                                  ),
                                  isThreeLine:
                                      description.isNotEmpty,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const NotificationsScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 60,
                color: brand,
              ),
              SizedBox(height: 12),
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your notification feed will appear here '
                'after the backend is connected.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class MapPickedLocation {
  final LatLng coordinates;
  final String name;

  const MapPickedLocation(this.coordinates, this.name);
}
class MapLocationPicker extends StatefulWidget {
  final LatLng initialLocation;

  const MapLocationPicker({
    super.key,
    required this.initialLocation,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late LatLng selectedLocation;
  late final MapController mapController;

  final searchController = TextEditingController();

  String selectedPlaceName = 'Selected location';
  List<dynamic> searchResults = [];
  bool searching = false;
  String? searchError;

  @override
  void initState() {
    super.initState();
    selectedLocation = widget.initialLocation;
    mapController = MapController();
    _reverseSearch(selectedLocation);
  }

  String _getPlaceName(Map<String, dynamic> p) {
    final parts = [
      p['name'],
      p['district'],
      p['city'],
      p['state'],
      p['country'],
    ];

    final names = <String>[];
    for (final part in parts) {
      final value = part?.toString().trim() ?? '';
      if (value.isNotEmpty && !names.contains(value)) {
        names.add(value);
      }
    }

    return names.isEmpty ? 'Unknown location' : names.join(', ');
  }

  Future<void> searchPlaces() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      searching = true;
      searchError = null;
      searchResults = [];
    });

    try {
      final uri = Uri.https(
        'photon.komoot.io',
        '/api/',
        {'q': query, 'limit': '6'},
      );


      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'SkillSwap/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      debugPrint('PLACE SEARCH STATUS: ${response.statusCode}');
      debugPrint('PLACE SEARCH BODY: ${response.body}');
      debugPrint('PLACE SEARCH STATUS: ${response.statusCode}');
      debugPrint('PLACE SEARCH BODY: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Search service unavailable');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      if (!mounted) return;

      setState(() {
        searchResults = features;
        if (features.isEmpty) {
          searchError = 'No places found. Try another name.';
        }
      });
        } catch (e) {
          debugPrint('PLACE SEARCH ERROR: $e');
          if (mounted) {
            setState(() => searchError = 'Search error: $e');
          }
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  void selectSearchResult(dynamic feature) {
    final properties =
        Map<String, dynamic>.from(feature['properties'] as Map);
    final coordinates =
        feature['geometry']['coordinates'] as List<dynamic>;

    final point = LatLng(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );

    setState(() {
      selectedLocation = point;
      selectedPlaceName = _getPlaceName(properties);
      searchResults = [];
      searchController.text = selectedPlaceName;
    });

    mapController.move(point, 15);
  }

  Future<void> _reverseSearch(LatLng point) async {
    try {
      final uri = Uri.https(
        'photon.komoot.io',
        '/reverse',
        {
          'lat': point.latitude.toString(),
          'lon': point.longitude.toString(),
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 12),
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      if (features.isEmpty || !mounted) return;

      final properties =
          Map<String, dynamic>.from(features.first['properties'] as Map);

      setState(() {
        selectedPlaceName = _getPlaceName(properties);
      });
    } catch (_) {
      // Keep coordinates if reverse search is unavailable.
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose your location'),
      content: SizedBox(
        width: 500,
        height: 480,
        child: Column(
          children: [
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => searchPlaces(),
              decoration: InputDecoration(
                hintText: 'Search city, area or place',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: searching ? null : searchPlaces,
                  icon: searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),

            if (searchError != null)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  searchError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            if (searchResults.isNotEmpty)
              SizedBox(
                height: 115,
                child: ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final feature = searchResults[index];
                    final properties = Map<String, dynamic>.from(
                      feature['properties'] as Map,
                    );

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(_getPlaceName(properties)),
                      onTap: () => selectSearchResult(feature),
                    );
                  },
                ),
              ),

            Expanded(
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: widget.initialLocation,
                  initialZoom: 13,
                  onTap: (tapPosition, point) {
                    setState(() {
                      selectedLocation = point;
                      selectedPlaceName = 'Finding place...';
                      searchResults = [];
                    });
                    _reverseSearch(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selectedLocation,
                        width: 45,
                        height: 45,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 45,
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'Tiles © Esri — Sources: Esri, HERE, USGS, and others',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text(
              selectedPlaceName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Lat: ${selectedLocation.latitude.toStringAsFixed(6)}'
              ' | Lng: ${selectedLocation.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            MapPickedLocation(selectedLocation, selectedPlaceName),
          ),
          child: const Text('Select location'),
        ),
      ],
    );
  }
}

