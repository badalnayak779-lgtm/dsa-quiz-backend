import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  runApp(const AIQuizApp());
}

// ============================================================
// CONFIGURATION
// ============================================================
//
// Android emulator:
//   http://10.0.2.2:3000
//
// iOS simulator:
//   http://127.0.0.1:3000
//
// Physical phone:
//   http://YOUR_COMPUTER_IP:3000
//
// Example:
//   http://192.168.1.10:3000
//
const String backendUrl = "https://dsa-quiz-backend.onrender.com";


// ============================================================
// APP
// ============================================================

class AIQuizApp extends StatelessWidget {
  const AIQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AI DSA Quiz",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}


// ============================================================
// MODELS
// ============================================================

class QuizQuestion {
  final int id;
  final String subject;
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.subject,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json["id"],
      subject: json["subject"],
      question: json["question"],
      options: List<String>.from(json["options"]),
      correctAnswer: json["correctAnswer"],
      explanation: json["explanation"],
    );
  }
}


// ============================================================
// API SERVICE
// ============================================================

class ApiService {
  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    String? userId = prefs.getString("user_id");

    if (userId == null) {
      userId =
      "user_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey()}";

      await prefs.setString("user_id", userId);
    }

    return userId;
  }

  static Future<List<QuizQuestion>> generateQuiz({
    required List<String> subjects,
    required String difficulty,
  }) async {
    final userId = await getUserId();

    final response = await http.post(
      Uri.parse("$backendUrl/api/generate-quiz"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "userId": userId,
        "subjects": subjects,
        "difficulty": difficulty,
      }),
    );

    if (response.statusCode != 200) {
      String message = "Failed to generate quiz.";

      try {
        final data = jsonDecode(response.body);
        message = data["error"] ?? message;
      } catch (_) {}

      throw Exception(message);
    }

    final data = jsonDecode(response.body);

    final List questions = data["questions"];

    return questions
        .map(
          (question) => QuizQuestion.fromJson(question),
    )
        .toList();
  }

  static Future<Map<String, dynamic>> getHistory() async {
    final userId = await getUserId();

    final response = await http.get(
      Uri.parse("$backendUrl/api/history/$userId"),
    );

    if (response.statusCode != 200) {
      throw Exception("Could not load history.");
    }

    return jsonDecode(response.body);
  }
}


// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Set<String> selectedSubjects = {
    "DSA",
    "DBMS",
    "C++",
  };

  String difficulty = "medium";

  bool loading = false;

  Future<void> startQuiz() async {
    if (selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select at least one subject."),
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final questions = await ApiService.generateQuiz(
        subjects: selectedSubjects.toList(),
        difficulty: difficulty,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPage(
            questions: questions,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst("Exception: ", ""),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void toggleSubject(String subject) {
    setState(() {
      if (selectedSubjects.contains(subject)) {
        selectedSubjects.remove(subject);
      } else {
        selectedSubjects.add(subject);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI DSA Quiz"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              const Text(
                "Prepare smarter.",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "AI-generated DSA, DBMS and C++ questions.",
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "Subjects",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  subjectChip("DSA"),
                  subjectChip("DBMS"),
                  subjectChip("C++"),
                ],
              ),

              const SizedBox(height: 35),

              const Text(
                "Difficulty",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: "easy",
                    label: Text("Easy"),
                  ),
                  ButtonSegment(
                    value: "medium",
                    label: Text("Medium"),
                  ),
                  ButtonSegment(
                    value: "hard",
                    label: Text("Hard"),
                  ),
                ],
                selected: {difficulty},
                onSelectionChanged: (value) {
                  setState(() {
                    difficulty = value.first;
                  });
                },
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: loading ? null : startQuiz,
                  icon: loading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    loading
                        ? "Generating questions..."
                        : "START QUIZ",
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget subjectChip(String subject) {
    return FilterChip(
      label: Text(subject),
      selected: selectedSubjects.contains(subject),
      onSelected: (_) => toggleSubject(subject),
    );
  }
}


// ============================================================
// QUIZ PAGE
// ============================================================

class QuizPage extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizPage({
    super.key,
    required this.questions,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int currentIndex = 0;

  int score = 0;

  int? selectedAnswer;

  bool answered = false;

  QuizQuestion get currentQuestion =>
      widget.questions[currentIndex];

  void selectAnswer(int index) {
    if (answered) return;

    setState(() {
      selectedAnswer = index;
      answered = true;

      if (index == currentQuestion.correctAnswer) {
        score++;
      }
    });
  }

  void nextQuestion() {
    if (currentIndex == widget.questions.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            score: score,
            total: widget.questions.length,
          ),
        ),
      );

      return;
    }

    setState(() {
      currentIndex++;
      selectedAnswer = null;
      answered = false;
    });
  }

  Color optionColor(int index) {
    if (!answered) {
      return Theme.of(context).colorScheme.surface;
    }

    if (index == currentQuestion.correctAnswer) {
      return Colors.green.withOpacity(0.15);
    }

    if (index == selectedAnswer) {
      return Colors.red.withOpacity(0.15);
    }

    return Theme.of(context).colorScheme.surface;
  }

  IconData? optionIcon(int index) {
    if (!answered) return null;

    if (index == currentQuestion.correctAnswer) {
      return Icons.check_circle;
    }

    if (index == selectedAnswer) {
      return Icons.cancel;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final question = currentQuestion;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${currentIndex + 1} / ${widget.questions.length}",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value:
              (currentIndex + 1) / widget.questions.length,
            ),

            const SizedBox(height: 20),

            Chip(
              label: Text(question.subject),
            ),

            const SizedBox(height: 20),

            Text(
              question.question,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            Expanded(
              child: ListView.builder(
                itemCount: question.options.length,
                itemBuilder: (context, index) {
                  final icon = optionIcon(index);

                  return Card(
                    color: optionColor(index),
                    margin: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => selectAnswer(index),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              child: Text(
                                String.fromCharCode(
                                  65 + index,
                                ),
                              ),
                            ),

                            const SizedBox(width: 15),

                            Expanded(
                              child: Text(
                                question.options[index],
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            if (icon != null)
                              Icon(icon),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (answered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.blue.withOpacity(0.08),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedAnswer ==
                          question.correctAnswer
                          ? "Correct! 🎉"
                          : "Incorrect",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(question.explanation),
                  ],
                ),
              ),

              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: answered ? nextQuestion : null,
                child: Text(
                  currentIndex ==
                      widget.questions.length - 1
                      ? "FINISH"
                      : "NEXT QUESTION",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// RESULT PAGE
// ============================================================

class ResultPage extends StatelessWidget {
  final int score;
  final int total;

  const ResultPage({
    super.key,
    required this.score,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = ((score / total) * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Result"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 90,
              ),

              const SizedBox(height: 25),

              const Text(
                "Quiz Complete!",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "$score / $total",
                style: const TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                "$percentage% accuracy",
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("NEW QUIZ"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// HISTORY PAGE
// ============================================================

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool loading = true;

  Map<String, dynamic>? history;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final data = await ApiService.getHistory();

      setState(() {
        history = data;
        loading = false;
      });
    } catch (_) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final questions =
        (history?["questions"] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Question History"),
      ),
      body: questions.isEmpty
          ? const Center(
        child: Text(
          "No questions yet.",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];

          return Card(
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(
                      question["subject"],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    question["question"],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}