import 'dart:math';

double calculateScore(int goodResponses, int badResponses) {
  final totalVotes = goodResponses + badResponses;
  if (totalVotes == 0) return 0.5;

  final average = goodResponses / totalVotes;
  final score = average - (average - 0.5) * pow(2, -log(totalVotes + 1));

  return score;
}
