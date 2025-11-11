import 'dart:async';

// A data class to hold the animation payload.
class RhmAward {
  final int points;
  final String reason;

  RhmAward({required this.points, required this.reason});
}

class RhmAnimationService {
  // The stream now broadcasts our new RhmAward object.
  final _pointsAwardedController = StreamController<RhmAward>.broadcast();

  // Public stream for the UI to listen to.
  Stream<RhmAward> get onPointsAwarded => _pointsAwardedController.stream;

  // Method to trigger the animation with points and a reason.
  void awardPoints(int points, String reason) {
    if (points > 0) {
      _pointsAwardedController.add(RhmAward(points: points, reason: reason));
    }
  }

  void dispose() {
    _pointsAwardedController.close();
  }
}

final rhmAnimationService = RhmAnimationService();
