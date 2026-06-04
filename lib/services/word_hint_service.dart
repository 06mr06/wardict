import 'dart:math';

class WordHintService {
  static final WordHintService instance = WordHintService._();
  WordHintService._();

  final Random _random = Random();

  final Map<String, List<String>> _hints = {
    'be': ['To ___ or not to ___, that is the question.', 'I want to ___ a doctor when I grow up.'],
    'have': ['I ____ a beautiful dream last night.', 'Do you ____ a minute to talk?'],
    'do': ['What are you ___ing right now?', 'Please ___ your homework before dinner.'],
    'say': ['What did you ___ to him?', 'It is easy to ___ but hard to do.'],
    'go': ['Let\'s ___ to the park today.', 'I need to ___ home now.'],
    'get': ['I need to ___ some milk from the store.', 'Did you ___ my message?'],
    'make': ['She can ____ delicious cakes.', 'Don\'t ____ a mess in the kitchen.'],
    'know': ['I don\'t ____ the answer to this question.', 'Do you ____ where he lives?'],
    'think': ['I _____ it is going to rain today.', 'What do you _____ about this book?'],
    'take': ['Please ____ an umbrella with you.', 'It will ____ about an hour to arrive.'],
    'see': ['Can you ___ the bird on the tree?', 'I hope to ___ you soon.'],
    'come': ['Please ____ inside, it is cold.', 'When did they ____ back?'],
    'want': ['I ____ to travel around the world.', 'Do you ____ some coffee?'],
    'look': ['____ at the beautiful stars!', 'She is ___ing for her keys.'],
    'use': ['How do you ___ this machine?', 'You should ___ a dictionary for new words.'],
    'find': ['I can\'t ____ my phone anywhere.', 'Did you ____ what you were looking for?'],
    'give': ['Please ____ me a hand with this box.', 'He likes to ____ gifts to his friends.'],
    'tell': ['Don\'t ____ anyone my secret.', 'Can you ____ me a story?'],
    'work': ['I have to ____ late today.', 'This remote control doesn\'t ____.'],
    'call': ['Please ____ me when you arrive.', 'What do you ____ this in English?'],
    'try': ['You should ____ this new restaurant.', 'I will ____ my best to help you.'],
    'ask': ['Can I ___ you a favor?', 'Don\'t be afraid to ___ questions.'],
    'need': ['I ____ some water to drink.', 'Do you ____ any help?'],
    'feel': ['I ____ much better today.', 'How do you ____ about the news?'],
    'become': ['He wants to ______ a pilot.', 'The weather is ______ing colder.'],
    // ... Daha fazla kelime eklenebilir
  };

  String? getHint(String englishWord) {
    final word = englishWord.toLowerCase().trim();
    
    if (_hints.containsKey(word)) {
      final list = _hints[word]!;
      return list[_random.nextInt(list.length)];
    }

    // Genel ipucu şablonları (Otomatik Üretim)
    final templates = [
      'Can you use "$word" in a sentence?',
      'Thinking about the meaning of "$word"...',
      'This word is common in daily English.',
      'Try to remember the Turkish meaning of "$word".',
    ];

    return templates[_random.nextInt(templates.length)];
  }
}
