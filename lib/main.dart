
import 'package:flutter/material.dart';
import 'api_service.dart';

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
      home: const WelcomeScreen(),
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
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
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
          content: Text(
            'Password must be at least 6 characters.',
          ),
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
            content: Text('Username already exists. Choose another.'),
          ),
        );
        return;
      }

      setState(() {
        isUsernameAvailable = true;
        usernameMessage = 'Username is available';
        isCheckingUsername = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isCheckingUsername = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not verify username. Please try again.'),
        ),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });

    try {
      
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
          content: Text(
            'Account created successfully!',
          ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration failed: ${e.toString().replaceFirst('Exception: ', '')}',
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
                          onChanged: (value) {
                            checkUsernameAvailability(value);
                          },
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
                            padding: const EdgeInsets.only(top: 6, left: 8),
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

            TextField(
              controller: teachSkillController,
              decoration: InputDecoration(
                labelText: 'Skill I Can Teach',
                hintText: 'Example: Photoshop',
                prefixIcon: const Icon(Icons.school),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: learnSkillController,
              decoration: InputDecoration(
                labelText: 'Skill I Want to Learn',
                hintText: 'Example: Web Development',
                prefixIcon: const Icon(Icons.auto_stories),
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
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: teal,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Explore skills'),
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
            _DashboardCard(
              icon: Icons.account_circle_rounded,
              color: const Color(0xFF2563EB),
              title: 'My Profile',
              subtitle: 'View your account and skill information.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      name: name,
                      email: email,
                      teachSkill: teachSkill,
                      learnSkill: learnSkill,
                    ),
                  ),
                );
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
                builder: (_) => const SearchScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
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
            icon: Icon(Icons.search_rounded),
            label: 'Explore',
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
// ==================== PROFILE SCREEN ====================

class ProfileScreen extends StatelessWidget {
  final String name;
  final String email;
  final String teachSkill;
  final String learnSkill;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.teachSkill,
    required this.learnSkill,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 15),

            const CircleAvatar(
              radius: 50,
              child: Icon(
                Icons.person,
                size: 55,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              email,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.person,
                  color: Colors.indigo,
                ),
                title: const Text('Full Name'),
                subtitle: Text(name),
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.email,
                  color: Colors.indigo,
                ),
                title: const Text('Email'),
                subtitle: Text(email),
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.school,
                  color: Colors.indigo,
                ),
                title: const Text('Skill I Can Teach'),
                subtitle: Text(teachSkill),
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.auto_stories,
                  color: Colors.indigo,
                ),
                title: const Text('Skill I Want to Learn'),
                subtitle: Text(learnSkill),
              ),
            ),
          ],
        ),
      ),
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