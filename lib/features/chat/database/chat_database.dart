import 'package:hive/hive.dart';
import '../models/message_model.dart';

class ChatDatabase {
  final String _boxName = 'messageBox';

  Future<void> addMessage(MessageModel message) async {
    final box = await Hive.openBox<MessageModel>(_boxName);
    await box.add(message);
  }

  Future<List<MessageModel>> getMessages() async {
    final box = await Hive.openBox<MessageModel>(_boxName);
    return box.values.toList().cast<MessageModel>();
  }

  Future<void> clearMessages() async {
    final box = await Hive.openBox<MessageModel>(_boxName);
    await box.clear();
  }
}
