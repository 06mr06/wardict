import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/question_mode.dart';

abstract class BaseGameProvider extends ChangeNotifier {
  // Common State
  int index = 0;
  int score = 0;
  int streak = 0;
  
  // Abstract Getters
  int get totalQuestions;
  
  // UI Helpers (Model Agnostic)
  String get currentPrompt;
  List<String> get currentOptions;
  int get currentCorrectIndex;
  QuestionMode get currentMode;
  
  // derived specific model access can remain in the robust class
  
  // Actions
  void startSession(); // or init
  Future<void> answer(int selectedIndex, int timeLeft);
  void nextQuestion();
  
  bool get isFinished => index >= totalQuestions;
}

// Temporary Adapter until we fully unify models
// This helps BaseGameScreen call generic things without knowing about GeneratedQuestion vs Question
