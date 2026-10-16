
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'dart:convert';

void main() {
  runApp(const SkillSwapApp());
}

class SkillSwapApp extends StatelessWidget {
  const SkillSwapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillSwap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FA),
          foregroundColor: Color(0xFF172554),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        useMaterial3: true,
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Map<String, dynamic>?> _session =
      _loadSession();

  Future<Map<String, dynamic>?> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('skillswap_session');

    if (saved == null) return null;

    try {
      return Map<String, dynamic>.from(
        jsonDecode(saved) as Map,
      );
    } catch (_) {
      await prefs.remove('skillswap_session');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const WelcomeScreen();

        return HomeScreen(
          userId: (user['userId'] ?? '').toString(),
          name: (user['name'] ?? '').toString(),
          email: (user['email'] ?? '').toString(),
          teachSkill: (user['teachSkill'] ?? 'Not added yet').toString(),
          learnSkill: (user['learnSkill'] ?? 'Not added yet').toString(),
        );
      },
    );
  }
}

// ==================== WELCOME SCREEN ====================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.swap_horiz,
                size: 90,
                color: Colors.indigo,
              ),
              const SizedBox(height: 20),
              const Text(
                'SkillSwap',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Learn. Teach. Swap Skills.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== LOGIN SCREEN ====================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter email and password.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.login(
        email: email,
        password: password,
      );
final user = Map<String, dynamic>.from(data['user']);

final prefs = await SharedPreferences.getInstance();
await prefs.setString(
  'skillswap_session',
  jsonEncode({
    'userId': (user['user_id'] ?? '').toString(),
    'name': (user['full_name'] ?? email).toString(),
    'email': (user['email'] ?? email).toString(),
    'teachSkill': (user['teach_skill'] ?? 'Not added yet').toString(),
    'learnSkill': (user['learn_skill'] ?? 'Not added yet').toString(),
  }),
);
      if (!mounted) return;


            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  userId: (data['user']['user_id'] ?? '').toString(),
                  name: (data['user']['full_name'] ?? email).toString(),
                  email: (data['user']['email'] ?? email).toString(),
                  teachSkill:
                      (data['user']['teach_skill'] ?? 'Not added yet').toString(),
                  learnSkill:
                      (data['user']['learn_skill'] ?? 'Not added yet').toString(),
                ),
              ),
              (route) => false,
            );

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person,
              size: 70,
              color: Colors.indigo,
            ),
            const SizedBox(height: 25),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : loginUser,
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),

            const SizedBox(height: 15),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RegisterScreen(),
                  ),
                );
              },
              child: const Text(
                "Don't have an account? Register",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REGISTER SCREEN ====================

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final teachSkillController = TextEditingController();
  final learnSkillController = TextEditingController();

  bool isLoading = false;
  bool isCheckingUsername = false;
  bool? isUsernameAvailable;
  String usernameMessage = '';

  final List<String> skills = const [
    'Programming',
    'Web Development',
    'Graphic Design',
    'UI/UX Design',
    'Video Editing',
    'Photography',
    'Digital Marketing',
    'English',
    'Mathematics',
    'Other',
  ];

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    teachSkillController.dispose();
    learnSkillController.dispose();
    super.dispose();
  }

  Future<void> checkUsernameAvailability(String value) async {
    final username = value.trim();

    if (username.isEmpty) {
      setState(() {
        isUsernameAvailable = null;
        usernameMessage = '';
        isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      isCheckingUsername = true;
      isUsernameAvailable = null;
      usernameMessage = 'Checking username...';
    });

    try {
      final data = await ApiService.checkUsername(username);

      if (!mounted || usernameController.text.trim() != username) {
        return;
      }

      setState(() {
        isUsernameAvailable = data['available'] == true;
        usernameMessage = data['message']?.toString() ?? '';
      });
    } catch (e) {
      if (!mounted || usernameController.text.trim() != username) {
        return;
      }

      setState(() {
        isUsernameAvailable = null;
        usernameMessage = 'Could not check username. Try again.';
      });
    } finally {
      if (mounted && usernameController.text.trim() == username) {
        setState(() {
          isCheckingUsername = false;
        });
      }
    }
  }

  Future<void> registerUser() async {
    final name = nameController.text.trim();
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final teachSkill = teachSkillController.text.trim();
    final learnSkill = learnSkillController.text.trim();

    if (name.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        teachSkill.isEmpty ||
        learnSkill.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields.'),
        ),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email.'),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    setState(() {
      isCheckingUsername = true;
    });

    try {
      final usernameData =
          await ApiService.checkUsername(username);

      if (!mounted) return;

      if (usernameData['available'] != true) {
        setState(() {
          isCheckingUsername = false;
          isUsernameAvailable = false;
          usernameMessage = 'Username already exists';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Username already exists. Choose another.',
            ),
          ),
        );
        return;
      }

      setState(() {
        isUsernameAvailable = true;
        usernameMessage = 'Username is available';
        isCheckingUsername = false;
        isLoading = true;
      });

      final data = await ApiService.register(
        uniqueUsername: username,
        email: email,
        password: password,
        fullName: name,
        teachSkill: teachSkill,
        learnSkill: learnSkill,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            userId: (data['user_id'] ?? '').toString(),
            name: name,
            email: email,
            teachSkill: teachSkill,
            learnSkill: learnSkill,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $errorMessage'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isCheckingUsername = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            const Icon(
              Icons.person_add,
              size: 70,
              color: Colors.indigo,
            ),

            const SizedBox(height: 25),

            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: usernameController,
              onChanged: checkUsernameAvailability,
              decoration: InputDecoration(
                labelText: 'Unique Username',
                hintText: 'Example: sanjida123',
                prefixIcon: const Icon(Icons.alternate_email),
                suffixIcon: isCheckingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : isUsernameAvailable == null
                        ? null
                        : Icon(
                            isUsernameAvailable!
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: isUsernameAvailable!
                                ? Colors.green
                                : Colors.red,
                          ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (usernameMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  top: 6,
                  left: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    usernameMessage,
                    style: TextStyle(
                      color: isUsernameAvailable == true
                          ? Colors.green
                          : isUsernameAvailable == false
                              ? Colors.red
                              : Colors.grey,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 15),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue value) {
                            if (value.text.isEmpty) {
                              return skills;
                            }

                            return skills.where(
                              (skill) => skill.toLowerCase().contains(
                                value.text.toLowerCase(),
                              ),
                            );
                          },
                          onSelected: (value) {
                            teachSkillController.text = value;
                          },
                          fieldViewBuilder: (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              onChanged: (value) {
                                teachSkillController.text = value;
                              },
                              onSubmitted: (_) => onFieldSubmitted(),
                              decoration: InputDecoration(
                                labelText: 'Skill I Can Teach',
                                hintText: 'Type or select a skill',
                                prefixIcon: const Icon(Icons.school),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 15),

                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue value) {
                            if (value.text.isEmpty) {
                              return skills;
                            }

                            return skills.where(
                              (skill) => skill.toLowerCase().contains(
                                value.text.toLowerCase(),
                              ),
                            );
                          },
                          onSelected: (value) {
                            learnSkillController.text = value;
                          },
                          fieldViewBuilder: (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              onChanged: (value) {
                                learnSkillController.text = value;
                              },
                              onSubmitted: (_) => onFieldSubmitted(),
                              decoration: InputDecoration(
                                labelText: 'Skill I Want to Learn',
                                hintText: 'Type or select a skill',
                                prefixIcon: const Icon(Icons.auto_stories),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : registerUser,
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Register',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HOME SCREEN ====================


class HomeScreen extends StatelessWidget {
  final String userId;
  final String name;
  final String email;
  final String teachSkill;
  final String learnSkill;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.email,
    required this.teachSkill,
    required this.learnSkill,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const navy = Color(0xFF172554);
    const teal = Color(0xFF0F766E);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SkillSwap',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFD1FAE5),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: const TextStyle(
                  color: teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF164E63)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Welcome, $name!',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Learn something new. Share what you know.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),

                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Your learning journey',
              style: theme.textTheme.titleLarge?.copyWith(
                color: navy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Share your strengths and discover new ones.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 18),
            _DashboardCard(
              icon: Icons.travel_explore_rounded,
              color: const Color(0xFF0F766E),
              title: 'Find a Skill',
              subtitle: 'Discover skills and search for teachers.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchScreen(),
                  ),
                );
              },
            ),
            _DashboardCard(
              icon: Icons.auto_stories_rounded,
              color: const Color(0xFF6D5BD0),
              title: 'My Skills',
              subtitle: 'Teach: $teachSkill\nLearn: $learnSkill',
              onTap: () async {
                final result = await Navigator.push<Map<String, String>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MySkillsScreen(
                      userId: userId,
                      teachSkill: teachSkill,
                      learnSkill: learnSkill,
                    ),
                  ),
                );

                if (result != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomeScreen(
                        userId: userId,
                        name: name,
                        email: email,
                        teachSkill: result['teachSkill'] ?? teachSkill,
                        learnSkill: result['learnSkill'] ?? learnSkill,
                      ),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE6FFFA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: teal, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Every skill is worth sharing. Keep learning!',
                      style: TextStyle(
                        color: Color(0xFF115E59),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

bottomNavigationBar: BottomNavigationBar(
  currentIndex: 0,
  selectedItemColor: teal,
  unselectedItemColor: Colors.blueGrey,
  type: BottomNavigationBarType.fixed,
  onTap: (index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            userId: userId,
            name: name,
            email: email,
            teachSkill: teachSkill,
            learnSkill: learnSkill,
          ),
        ),
      );
    }
  },
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ],
),

    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 27),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}


class MySkillsScreen extends StatefulWidget {
  final String userId;
  final String teachSkill;
  final String learnSkill;

  const MySkillsScreen({
    super.key,
    required this.userId,
    required this.teachSkill,
    required this.learnSkill,
  });

  @override
  State<MySkillsScreen> createState() => _MySkillsScreenState();
}

class _MySkillsScreenState extends State<MySkillsScreen> {
  late final TextEditingController teachController;
  late final TextEditingController learnController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    teachController = TextEditingController(text: widget.teachSkill);
    learnController = TextEditingController(text: widget.learnSkill);
  }

  @override
  void dispose() {
    teachController.dispose();
    learnController.dispose();
    super.dispose();
  }

  Future<void> saveSkills() async {
    if (widget.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID missing. Please login again.')),
      );
      return;
    }

    if (teachController.text.trim().isEmpty ||
        learnController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both skills.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await ApiService.updateSkills(
        userId: widget.userId,
        teachSkill: teachController.text.trim(),
        learnSkill: learnController.text.trim(),
      );

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Skills saved successfully!')),
            );

            Navigator.pop(context, {
              'teachSkill': teachController.text.trim(),
              'learnSkill': learnController.text.trim(),
            });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Skills'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your Skill Journey',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: teachController,
            decoration: const InputDecoration(
              labelText: 'Skills I Can Teach',
              prefixIcon: Icon(Icons.school),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: learnController,
            decoration: const InputDecoration(
              labelText: 'Skills I Want to Learn',
              prefixIcon: Icon(Icons.menu_book),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isSaving ? null : saveSkills,
            icon: const Icon(Icons.save),
            label: Text(isSaving ? 'Saving...' : 'Save Skills'),
          ),
        ],
      ),
    );
  }
}



 // ==================== PROFILE SCREEN ====================

 class ProfileScreen extends StatefulWidget {
   final String userId;
   final String name;
   final String email;
   final String teachSkill;
   final String learnSkill;

   const ProfileScreen({
     super.key,
     required this.userId,
     required this.name,
     required this.email,
     required this.teachSkill,
     required this.learnSkill,
   });

   @override
   State<ProfileScreen> createState() => _ProfileScreenState();
 }

 class _ProfileScreenState extends State<ProfileScreen> {
   late String currentName;
   late String currentBio;
   late String currentTeachSkill;
   late String currentLearnSkill;
   Map<String, dynamic>? ratingsData;
   bool isLoadingRatings = true;
   String? ratingsError;

   late final TextEditingController nameController;
   late final TextEditingController bioController;
   late final TextEditingController teachController;
   late final TextEditingController learnController;

   @override
   void initState() {
     super.initState();

     currentName = widget.name;
     currentBio =
         'I am part of the SkillSwap community, where I share what I know and learn something new from others.';
     currentTeachSkill = widget.teachSkill;
     currentLearnSkill = widget.learnSkill;

     nameController = TextEditingController(text: currentName);
     bioController = TextEditingController(text: currentBio);
     teachController = TextEditingController(text: currentTeachSkill);
     learnController = TextEditingController(text: currentLearnSkill);

     _loadProfile();
     _loadRatings();
   }

Future<void> _loadProfile() async {
  try {
    final data = await ApiService.getProfile(widget.userId);

    if (!mounted) return;

    final profile = data['profile'] is Map
        ? Map<String, dynamic>.from(data['profile'])
        : data['user'] is Map
            ? Map<String, dynamic>.from(data['user'])
            : data;

    setState(() {
      currentName = profile['full_name'] ?? widget.name;
      currentBio = profile['bio'] ??
          'I am part of the SkillSwap community, where I share what I know and learn something new from others.';
      currentTeachSkill =
          profile['teach_skill'] ?? widget.teachSkill;
      currentLearnSkill =
          profile['learn_skill'] ?? widget.learnSkill;

      nameController.text = currentName;
      bioController.text = currentBio;
      teachController.text = currentTeachSkill;
      learnController.text = currentLearnSkill;
    });
  } catch (e) {
    debugPrint('Profile loading failed: $e');
  }
}
Future<void> _loadRatings() async {
  try {
    final data = await ApiService.getRatings(widget.userId);

    if (!mounted) return;

    setState(() {
      ratingsData = data;
      ratingsError = null;
      isLoadingRatings = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      ratingsError = e.toString();
      isLoadingRatings = false;
    });
  }
}

   @override
   void dispose() {
     nameController.dispose();
     bioController.dispose();
     teachController.dispose();
     learnController.dispose();
     super.dispose();
   }

   @override
   Widget build(BuildContext context) {
     const navy = Color(0xFF172554);
     const teal = Color(0xFF0F766E);
     const pageColor = Color(0xFFF4F7FB);

     return Scaffold(
       backgroundColor: pageColor,
       appBar: AppBar(
         backgroundColor: pageColor,
         foregroundColor: navy,
         elevation: 0,
         centerTitle: true,
         title: const Text(
           'My Profile',
           style: TextStyle(
             fontWeight: FontWeight.bold,
             fontSize: 21,
           ),
         ),
         actions: [
           IconButton(
             tooltip: 'Settings',
             icon: const Icon(Icons.settings_outlined),
             onPressed: () {
               showDialog<void>(
                 context: context,
                 builder: (dialogContext) => AlertDialog(
                   title: const Text('Settings'),
                   content: const Text(
                     'Log out of your SkillSwap account?',
                   ),
                   actions: [
                     TextButton(
                       onPressed: () => Navigator.pop(dialogContext),
                       child: const Text('Cancel'),
                     ),
                     FilledButton.icon(
                       icon: const Icon(Icons.logout),
                       label: const Text('Logout'),
                       onPressed: () async {
                         Navigator.pop(dialogContext);

                         final prefs = await SharedPreferences.getInstance();
                         await prefs.remove('skillswap_session');

                         if (!context.mounted) return;

                         Navigator.of(context).pushAndRemoveUntil(
                           MaterialPageRoute(
                             builder: (_) => const WelcomeScreen(),
                           ),
                           (route) => false,
                         );
                       },
                     ),
                   ],
                 ),
               );
             },
           ),
         ],
       ),
       body: SingleChildScrollView(
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Cover banner
             Container(
               height: 155,
               width: double.infinity,
               decoration: const BoxDecoration(
                 gradient: LinearGradient(
                   colors: [
                     Color(0xFF172554),
                     Color(0xFF0F766E),
                     Color(0xFF2DD4BF),
                   ],
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                 ),
                 borderRadius: BorderRadius.only(
                   bottomLeft: Radius.circular(30),
                   bottomRight: Radius.circular(30),
                 ),
               ),
               child: Stack(
                 children: [
                   Positioned(
                     right: 18,
                     top: 18,
                     child: Icon(
                       Icons.auto_awesome,
                       size: 45,
                       color: Colors.white.withValues(alpha: 0.35),
                     ),
                   ),
                   Positioned(
                     right: 75,
                     bottom: 18,
                     child: Icon(
                       Icons.menu_book_rounded,
                       size: 65,
                       color: Colors.white.withValues(alpha: 0.18),
                     ),
                   ),
                   const Positioned(
                     left: 22,
                     top: 22,
                     child: Text(
                       'YOUR SKILLS. YOUR FUTURE.',
                       style: TextStyle(
                         color: Colors.white,
                         fontSize: 12,
                         fontWeight: FontWeight.w600,
                         letterSpacing: 1.3,
                       ),
                     ),
                   ),
                 ],
               ),
             ),

             // Profile information
             Transform.translate(
               offset: const Offset(0, -45),
               child: Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 22),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       crossAxisAlignment: CrossAxisAlignment.end,
                       children: [
                         Container(
                           padding: const EdgeInsets.all(4),
                           decoration: const BoxDecoration(
                             color: Colors.white,
                             shape: BoxShape.circle,
                           ),
                           child: CircleAvatar(
                             radius: 48,
                             backgroundColor: const Color(0xFFD1FAE5),
                             child: Text(
                               currentName.trim().isNotEmpty
                                   ? currentName.trim()[0].toUpperCase()
                                   : 'S',
                               style: const TextStyle(
                                 fontSize: 36,
                                 fontWeight: FontWeight.bold,
                                 color: teal,
                               ),
                             ),
                           ),
                         ),
                         const Spacer(),
                         Padding(
                           padding: const EdgeInsets.only(bottom: 5),
                           child: OutlinedButton.icon(
                             onPressed: () => _showEditProfileDialog(context),
                             icon: const Icon(
                               Icons.edit_outlined,
                               size: 17,
                             ),
                             label: const Text('Edit Profile'),
                             style: OutlinedButton.styleFrom(
                               foregroundColor: teal,
                               side: const BorderSide(color: teal),
                               backgroundColor: Colors.white,
                               shape: RoundedRectangleBorder(
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               padding: const EdgeInsets.symmetric(
                                 horizontal: 12,
                                 vertical: 10,
                               ),
                             ),
                           ),
                         ),
                       ],
                     ),

                     const SizedBox(height: 10),

                     Text(
                       currentName,
                       style: const TextStyle(
                         fontSize: 26,
                         fontWeight: FontWeight.bold,
                         color: navy,
                       ),
                     ),

                     const SizedBox(height: 7),

                     Row(
                       children: [
                         const Icon(
                           Icons.email_outlined,
                           color: teal,
                           size: 18,
                         ),
                         const SizedBox(width: 7),
                         Expanded(
                           child: Text(
                             widget.email,
                             style: const TextStyle(
                               color: Color(0xFF64748B),
                               fontSize: 14,
                             ),
                           ),
                         ),
                       ],
                     ),

                     const SizedBox(height: 20),

                     _profileSectionTitle(
                       'About Me',
                       Icons.person_outline_rounded,
                     ),
                     const SizedBox(height: 11),
                     _profileCard(
                       child: Text(
                         currentBio.isEmpty
                             ? 'No bio added yet.'
                             : currentBio,
                         style: const TextStyle(
                           color: Color(0xFF475569),
                           fontSize: 14,
                           height: 1.7,
                         ),
                       ),
                     ),

                     const SizedBox(height: 24),

                     _profileSectionTitle(
                       'Skills I Can Teach',
                       Icons.school_rounded,
                     ),
                     const SizedBox(height: 11),
                     _profileCard(
                       child: _buildSkillChips(
                         currentTeachSkill,
                         const Color(0xFFD1FAE5),
                         const Color(0xFF065F46),
                         Icons.lightbulb_outline_rounded,
                       ),
                     ),

                     const SizedBox(height: 24),

                     _profileSectionTitle(
                       'Skills I Want to Learn',
                       Icons.auto_stories_rounded,
                     ),
                     const SizedBox(height: 11),
                     _profileCard(
                       child: _buildSkillChips(
                         currentLearnSkill,
                         const Color(0xFFDBEAFE),
                         const Color(0xFF1D4ED8),
                         Icons.menu_book_rounded,
                       ),
                     ),

                     const SizedBox(height: 24),

                     _profileSectionTitle(
                       'Learning Activity',
                       Icons.insights_rounded,
                     ),
                     const SizedBox(height: 11),
                     _profileCard(
                       child: const Row(
                         children: [
                           Expanded(
                             child: _ProfileStat(
                               icon: Icons.event_available_rounded,
                               value: '—',
                               label: 'Sessions',
                               color: Color(0xFF0F766E),
                             ),
                           ),
                           Expanded(
                             child: _ProfileStat(
                               icon: Icons.workspace_premium_rounded,
                               value: '—',
                               label: 'Skills Shared',
                               color: Color(0xFF7C3AED),
                             ),
                           ),
                           Expanded(
                             child: _ProfileStat(
                               icon: Icons.trending_up_rounded,
                               value: '—',
                               label: 'Skills Learned',
                               color: Color(0xFF2563EB),
                             ),
                           ),
                         ],
                       ),
                     ),

                     const SizedBox(height: 24),

                     _profileSectionTitle(
                       'Ratings & Reviews',
                       Icons.star_rounded,
                     ),
                     const SizedBox(height: 11),
                     _profileCard(
                       child: Builder(
                         builder: (context) {
                           if (isLoadingRatings) {
                             return const Center(
                               child: Padding(
                                 padding: EdgeInsets.all(20),
                                 child: CircularProgressIndicator(),
                               ),
                             );
                           }

                           if (ratingsError != null) {
                             return Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 const Text('Could not load ratings.'),
                                 const SizedBox(height: 8),
                                 Text(
                                   ratingsError!,
                                   style: const TextStyle(color: Colors.red),
                                 ),
                                 TextButton(
                                   onPressed: _loadRatings,
                                   child: const Text('Try again'),
                                 ),
                               ],
                             );
                           }

                           final data = ratingsData ?? {};
                           final average =
                               (data['average_rating'] as num?)?.toDouble() ?? 0.0;
                           final reviews = data['reviews'] is List
                               ? data['reviews'] as List
                               : <dynamic>[];
                           final count = (data['count'] as num?)?.toInt() ?? reviews.length;

                           if (reviews.isEmpty) {
                             return const ListTile(
                               leading: Icon(
                                 Icons.star_outline_rounded,
                                 color: Color(0xFFD97706),
                                 size: 32,
                               ),
                               title: Text('No reviews yet'),
                               subtitle: Text(
                                 'Reviews from other learners will appear here.',
                               ),
                             );
                           }

                           return Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 children: [
                                   const Icon(
                                     Icons.star_rounded,
                                     color: Color(0xFFD97706),
                                     size: 30,
                                   ),
                                   const SizedBox(width: 8),
                                   Text(
                                     average.toStringAsFixed(1),
                                     style: const TextStyle(
                                       fontSize: 25,
                                       fontWeight: FontWeight.bold,
                                       color: navy,
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Expanded(child: Text('$count reviews')),
                                   IconButton(
                                     tooltip: 'Refresh reviews',
                                     onPressed: _loadRatings,
                                     icon: const Icon(Icons.refresh),
                                   ),
                                 ],
                               ),
                               const Divider(),
                               ...reviews.map((item) {
                                 final review = Map<String, dynamic>.from(item as Map);
                                 final reviewer =
                                     (review['reviewer_username'] ?? 'Learner').toString();
                                 final rating =
                                     (review['rating'] as num?)?.toInt() ?? 0;
                                 final comment = (review['review'] ?? '').toString();
                                 final date = (review['created_at'] ?? '').toString();

                                 return Padding(
                                   padding: const EdgeInsets.symmetric(vertical: 10),
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Row(
                                         children: [
                                           const Icon(Icons.person_outline),
                                           const SizedBox(width: 8),
                                           Expanded(
                                             child: Text(
                                               reviewer,
                                               style: const TextStyle(
                                                 fontWeight: FontWeight.bold,
                                               ),
                                             ),
                                           ),
                                           Text('$rating/5'),
                                         ],
                                       ),
                                       Row(
                                         children: List.generate(
                                           5,
                                           (index) => Icon(
                                             index < rating
                                                 ? Icons.star_rounded
                                                 : Icons.star_outline_rounded,
                                             color: const Color(0xFFD97706),
                                             size: 18,
                                           ),
                                         ),
                                       ),
                                       if (comment.isNotEmpty) ...[
                                         const SizedBox(height: 6),
                                         Text(comment),
                                       ],
                                       if (date.isNotEmpty) ...[
                                         const SizedBox(height: 5),
                                         Text(
                                           date,
                                           style: const TextStyle(
                                             fontSize: 11,
                                             color: Color(0xFF64748B),
                                           ),
                                         ),
                                       ],
                                     ],
                                   ),
                                 );
                               }),
                             ],
                           );
                         },
                       ),
                     ),

                     const SizedBox(height: 20),

                     Center(
                       child: Text(
                         'Learn • Share • Grow with SkillSwap',
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           fontSize: 12,
                           color: Colors.blueGrey.shade400,
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                     ),

                     const SizedBox(height: 20),
                   ],
                 ),
               ),
             ),
           ],
         ),
       ),
     );
   }


  // Edit Profile dialog
  void _showEditProfileDialog(BuildContext context) {
    nameController.text = currentName;
    bioController.text = currentBio;
    teachController.text = currentTeachSkill;
    learnController.text = currentLearnSkill;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: teachController,
                decoration: const InputDecoration(
                  labelText: 'Skills I Can Teach',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: learnController,
                decoration: const InputDecoration(
                  labelText: 'Skills I Want to Learn',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name cannot be empty'),
                  ),
                );
                return;
              }

              try {
                final result = await ApiService.updateProfile(
                  userId: widget.userId,
                  fullName: nameController.text.trim(),
                  bio: bioController.text.trim(),
                  teachSkill: teachController.text.trim(),
                  learnSkill: learnController.text.trim(),
                );

                if (!mounted || !dialogContext.mounted) return;

                setState(() {
                  currentName = nameController.text.trim();
                  currentBio = bioController.text.trim();
                  currentTeachSkill = teachController.text.trim();
                  currentLearnSkill = learnController.text.trim();
                });

                Navigator.pop(dialogContext);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['message'] ?? 'Profile saved successfully!',
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not save profile: $e'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _profileSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF0F766E),
          size: 23,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172554),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172554).withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSkillChips(
    String skillText,
    Color backgroundColor,
    Color textColor,
    IconData icon,
  ) {
    final skillList = skillText
        .split(',')
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toList();

    if (skillList.isEmpty) {
      return const Text(
        'No skills added yet',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skillList.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 6),
              Text(
                skill,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ProfileStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(height: 9),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Color(0xFF172554),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

 // ==================== SEARCH SCREEN ====================

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  List<dynamic> skills = [];
  bool isLoading = false;
  String? errorMessage;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadSkills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadSkills({String search = ''}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await ApiService.findSkills(search: search);

      if (!mounted) return;

      setState(() {
        skills = results;
        searchQuery = search;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Skills'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    loadSkills(search: value.trim());
                  },
                  decoration: InputDecoration(
                    labelText: 'Search skills',
                    hintText: 'Python, English, Flutter...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        loadSkills();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => loadSkills(
                              search: _searchController.text.trim(),
                            ),
                    icon: const Icon(Icons.search),
                    label: const Text('Search Skills'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 52,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load skills',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => loadSkills(
                  search: _searchController.text.trim(),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (skills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off,
                size: 58,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                searchQuery.isEmpty
                    ? 'No skills available yet'
                    : 'No skills found for "$searchQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try another keyword.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: skills.length,
      itemBuilder: (context, index) {
        final skill = skills[index] as Map<String, dynamic>;
        final name = (skill['name'] ?? 'Unnamed skill').toString();
        final category = (
          skill['category_name'] ??
          skill['category'] ??
          'General'
        ).toString();
        final description =
            (skill['description'] ?? '').toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.withValues(alpha: 0.12),
              child: const Icon(
                Icons.auto_stories,
                color: Colors.indigo,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category: $category'),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(description),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}