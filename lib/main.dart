import 'package:flutter/material.dart';

void main() {
  runApp(const SwapSkillApp());
}

class SwapSkillApp extends StatelessWidget {
  const SwapSkillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SwapSkill',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
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
                'SwapSkill',
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

              // LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
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

              // CREATE ACCOUNT BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
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

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(
                        name: 'SwapSkill User',
                        email: 'user@example.com',
                        teachSkill: 'Not added yet',
                        learnSkill: 'Not added yet',
                      ),
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

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
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
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController teachSkillController =
      TextEditingController();
  final TextEditingController learnSkillController =
      TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    teachSkillController.dispose();
    learnSkillController.dispose();
    super.dispose();
  }

  void registerUser() {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final teachSkill = teachSkillController.text.trim();
    final learnSkill = learnSkillController.text.trim();

    // Basic validation
    if (name.isEmpty ||
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

    // For now, data is passed to the Home/Profile screen.
    // No database or real authentication yet.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          name: name,
          email: email,
          teachSkill: teachSkill,
          learnSkill: learnSkill,
        ),
      ),
    );
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

            // FULL NAME
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

            // EMAIL
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

            // PASSWORD
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

            // SKILL TO TEACH
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

            // SKILL TO LEARN
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

            // REGISTER BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: registerUser,
                child: const Text(
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
  final String name;
  final String email;
  final String teachSkill;
  final String learnSkill;

  const HomeScreen({
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
        title: const Text('SwapSkill'),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $name!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Exchange your skills with other learners.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            // FIND A SKILL
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.search,
                  color: Colors.indigo,
                ),
                title: const Text('Find a Skill'),
                subtitle: const Text(
                  'Search for people who can teach you.',
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Skill search will be added next.'),
                    ),
                  );
                },
              ),
            ),

            // MY SKILLS
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.school,
                  color: Colors.indigo,
                ),
                title: const Text('My Skills'),
                subtitle: Text(
                  'I can teach: $teachSkill',
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You can teach: $teachSkill',
                      ),
                    ),
                  );
                },
              ),
            ),

            // MY PROFILE
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.person,
                  color: Colors.indigo,
                ),
                title: const Text('My Profile'),
                subtitle: const Text(
                  'View your profile information.',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        name: name,
                        email: email,
                        teachSkill: teachSkill,
                        learnSkill: learnSkill,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

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

            // PROFILE ICON
            const CircleAvatar(
              radius: 50,
              child: Icon(
                Icons.person,
                size: 55,
              ),
            ),

            const SizedBox(height: 20),

            // NAME
            Text(
              name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            // EMAIL
            Text(
              email,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            // PERSONAL INFORMATION
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

            // TEACH SKILL
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

            // LEARN SKILL
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