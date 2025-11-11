import 'package:cloud_firestore/cloud_firestore.dart';
import 'tip_model.dart';

class DailyTip {
  final TipModel tip;
  final DateTime date;

  DailyTip({
    required this.tip,
    required this.date,
  });

  factory DailyTip.fromMap(Map<String, dynamic> map) {
    return DailyTip(
      tip: TipModel.fromMap(map['tip']),
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tip': tip.toMap(),
      'date': Timestamp.fromDate(date),
    };
  }
}